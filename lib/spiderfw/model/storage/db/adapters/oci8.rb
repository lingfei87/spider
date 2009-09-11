require 'spiderfw/model/storage/db/db_storage'
require 'oci8'

module Spider; module Model; module Storage; module Db
    
    class OCI8 < DbStorage
        @capabilities = {
            :autoincrement => false,
            :sequences => true,
            :transactions => true
        }
        @reserved_keywords = superclass.reserved_keywords + ['oci8_row_num', 'file', 'uid']
        @safe_conversions = {
            'CHAR' => ['VARCHAR', 'CLOB'],
            'VARCHAR' => ['CLOB'],
            'NUMBER' => ['VARCHAR']
        }
        class << self; attr_reader :reserved_kewords, :safe_conversions end
        
        def self.base_types
            super << Spider::DataTypes::Binary
        end
        
        def self.new_connection(user, pass, dbname, role)
            conn ||= ::OCI8.new(user, pass, dbname, role)
            conn.autocommit = true
            return conn
        end
        
        def self.connection_alive?(conn)
            # TODO: move to ping method when ruby-oci8 2.x is stable
            begin
                conn.autocommit?
                return true
            rescue
                return false
            end
        end
        
        def disconnect
            begin
                @conn.autocommit = true if @conn
                super
            rescue
                self.class.remove_connection(@conn, @connection_params)
                @conn = nil
            end
        end
        
        def parse_url(url)
            # db:oracle://<username:password>:connect_role@<database>
            # where database is
            # the net8 connect string or
            # for Oracle client 10g or later, //hostname_or_ip:port_no/oracle_sid
            if (url =~ /.+:\/\/(?:(.+):(.+)(?::(.+))?@)?(.+)/)
                @user = $1
                @pass = $2
                @role = $3
                @dbname = $4
            else
                raise ArgumentError, "OCI8 url '#{url}' is invalid"
            end
            @connection_params = [@user, @pass, @dbname, @role]
        end
        

        def start_transaction
            connection.autocommit = false
        end
        
        def in_transaction?
            return @conn && !@conn.autocommit?
        end
        
        def commit
            @conn.commit if @conn
            disconnect
        end
        
        def rollback
            @conn.rollback
            disconnect
        end
        
        def prepare_value(type, value)
            value = super
            return OCI8NilValue.new(Spider::Model.ruby_type(type)) if (value == nil)
            case type.name
            when 'Spider::DataTypes::Binary'
                return OCI8::BLOB.new(@conn, value)
            end
            return value
        end
        
        def value_for_condition(type, value)
            return value if value.nil?
            super
        end
        
        def value_to_mapper(type, value)
            case type.name
            when 'Date', 'DateTime'
                return nil unless value
                return value.to_datetime if type == DateTime
                return value.to_date # FIXME: check what is returned, here we espect an OCI8::Date
            when 'Spider::DataTypes::Text'
                value =  value ? value.read : ''
            end
            return super(type, value)
        end

         def execute(sql, *bind_vars)
             begin
                 if (bind_vars && bind_vars.length > 0)
                     debug_vars = bind_vars.map{|var| var = var.to_s; var && var.length > 50 ? var[0..50]+"...(#{var.length-50} chars more)" : var}
                 end
                 @last_executed = [sql, bind_vars]
                 if (Spider.conf.get('storage.db.replace_debug_vars'))
                     cnt = -1
                     debug("oci8 executing: "+sql.gsub(/:\d+/){
                         v = bind_vars[cnt]
                         dv = debug_vars[cnt+=1]
                         v.is_a?(String) ? "'#{dv}'" : dv
                     })
                 else
                     debug_vars_str = debug_vars ? debug_vars.join(', ') : ''
                     debug("oci8 executing:\n#{sql}\n[#{debug_vars_str}]")
                 end
                 cursor = connection.parse(sql)
                 return cursor if (!cursor || cursor.is_a?(Fixnum))
                 bind_vars.each_index do |i|
                     var = bind_vars[i]
                     if (var.is_a?(OCI8NilValue))
                         cursor.bind_param(i+1, nil, var.type, 0)
                     else
                         cursor.bind_param(i+1, var)
                     end
                 end
                 res = cursor.exec
                 have_result = (cursor.type == ::OCI8::STMT_SELECT)
                 # @cursor = connection.exec(sql, *bind_vars)
                 if (have_result)
                     result = []
                     while (h = cursor.fetch_hash)
                         if block_given?
                              yield h
                          else
                              result << h
                          end
                     end
                 end
                 if (have_result)
                     unless block_given?
                         result.extend(StorageResult)
                         @last_result = result
                         return result
                     end
                 else
                     return res
                 end
             rescue => exc
                 disconnect
                 raise exc
             ensure
                 cursor.close if cursor
                 disconnect if @conn && !in_transaction?
             end
         end
         

         def prepare(sql)
             debug("oci8 preparing: #{sql}")
             return connection.parse(sql)
         end

         def execute_statement(stmt, *bind_vars)
             stmt.exec(bind_vars)
         end
         
         def total_rows
             return nil unless @last_executed
             q = @last_query.clone
             unless (q[:offset] || q[:limit])
                 return @last_result ? @last_result.length : nil
             end
             q.delete(:offset); q.delete(:limit)
             sql, vars = sql_select(q)
             res = execute("SELECT COUNT(*) AS N FROM (#{sql})", *vars)
             return nil unless res && res[0]
             return res[0]['N'].to_i
         end
         
         def sequence_next(sequence_name)
             res = execute("SELECT #{sequence_name}.NEXTVAL AS NEXT FROM DUAL")
             return res[0]['NEXT'].to_i
         end

         
         ##############################################################
         #   SQL methods                                              #
         ##############################################################
         
         
         def sql_select(query)
             @bind_cnt = 0
             # Spider::Logger.debug("SQL SELECT:")
             # Spider::Logger.debug(query)
             bind_vars = query[:bind_vars] || []
             if query[:limit] # Oracle is so braindead
                 replaced_fields = {}
                 replace_cnt = 0
                 # add first field to order if none is found; order is needed for limit
                 query[:order] << [query[:keys][0], 'desc'] if query[:order].length < 1
                 query[:order].each do |o|
                     field, direction = o
                     # i = query[:keys].index(field)
                     #   unless i
                     #       query[:keys].push(field)
                     #       i = query[:keys].length < 1
                     #   end
                     transformed = "O#{replace_cnt += 1}"
                     replaced_fields[field] = transformed
                     query[:keys] << "#{field} AS #{transformed}"
                 end
             end
             keys = sql_keys(query)
             order = sql_order(query)
             if (query[:limit])
                 keys += ", row_number() over (order by #{order}) oci8_row_num"
             end
             tables_sql, tables_values = sql_tables(query)
             sql = "SELECT #{keys} FROM #{tables_sql} "
             bind_vars += tables_values
             where, vals = sql_condition(query)
             bind_vars += vals
             sql += "WHERE #{where} " if where && !where.empty?
             order = sql_order(query)
             if (query[:limit])
                 if (query[:offset])
                     limit = "oci8_row_num between :#{@bind_cnt+=1} and :#{@bind_cnt+=1}"
                     bind_vars << query[:offset] + 1
                     bind_vars << query[:offset] + query[:limit]
                 else
                     limit = "oci8_row_num < :#{@bind_cnt+=1}"
                     bind_vars << query[:limit] + 1
                 end
                 replaced_fields.each do |f, repl|
                     order = order.gsub(f, repl)
                 end
                 sql = "SELECT * FROM (#{sql}) WHERE #{limit} order by #{order}"
             else
                 sql += "ORDER BY #{order} " if order && !order.empty?
             end
             return sql, bind_vars
         end
         
         def sql_limit(query)
             # already done in sql_condition
         end
         
         def sql_condition_value(key, comp, value, bound_vars=true)
             if (comp.to_s.downcase == 'ilike')
                 comp = 'like'
                 key = "UPPER(#{key})"
             end
             if (value.nil?)
                 comp = comp == '=' ? "IS" : "IS NOT"
                 sql = "#{key} #{comp} NULL"
             else
                 if comp.to_s.downcase == 'between'
                     if (bound_vars)
                         val0, val1 = value
                     else
                         val0 = ":#{(@bind_cnt += 1)}"; val1 = ":#{(@bind_cnt += 1)}"
                     end
                     sql = "#{key} #{comp} #{val0} AND #{val1}"
                 else
                     val = bound_vars ? ":#{(@bind_cnt += 1)}" : value
                     sql = "#{key} #{comp} #{val}"
                 end
                 
                 
             end
             return sql
         end
         
         def sql_insert(insert)
             @bind_cnt = 0
             keys = insert[:values].keys.join(', ')
             vals = insert[:values].values.map{":#{(@bind_cnt += 1)}"}
             vals = vals.join(', ')
             sql = "INSERT INTO #{insert[:table]} (#{keys}) " +
                   "VALUES (#{vals})"
             return [sql, insert[:values].values]
         end
         
         def sql_insert_values(insert)
             insert[:values].values.map{":#{(@bind_cnt += 1)}"}.join(', ')
         end
         
         def sql_update(query)
             @bind_cnt = 0
             super
         end
         
         def sql_update_values(update)
             update[:values].map{ |k, v| 
                 "#{k} = :#{(@bind_cnt += 1)}"
             }.join(', ')
         end
         
         def sql_delete(del, force=false)
             @bind_cnt = 0
             super
         end
         
         def sql_alter_field(table_name, name, type, attributes)
             ["ALTER TABLE #{table_name} MODIFY #{sql_table_field(name, type, attributes)}"]
         end
         
         def sequence_exists?(sequence_name)
             check = "select SEQUENCE_NAME from user_sequences where sequence_name = :1"
             res = execute(check, sequence_name)
             return res[0] ? true : false
         end
         
         def create_sequence(sequence_name, start=1, increment=1)
             execute("create sequence #{sequence_name} start with #{start} increment by #{increment}")
         end
         
         def update_sequence(name, val)
             execute("drop sequence #{name}")
             create_sequence(name, val)
         end
         
         ##############################################################
         #   Methods to get information from the db                   #
         ##############################################################

         def list_tables
             return execute("SELECT TABLE_NAME FROM user_tables ORDER BY table_name").map{ |r| r['TABLE_NAME'] }
         end

         def describe_table(table)
             columns = {}
             connection do |conn|
                 t = conn.describe_table(table)
                 t.columns.each do |c|
                     col = {
                         :type => c.data_type.to_s.upcase,
                         :length => c.data_size,
                         :precision => c.precision,
                         :scale => c.scale,
                         :null => c.nullable?
                     }
                     col.delete(:length) if (col[:precision])
                     columns[c.name] = col
                 end
             end
             return {:columns => columns}
         end

         def table_exists?(table)
             begin
                 connection do |c|
                     c.describe_table(table)
                 end
                 Spider.logger.debug("TABLE EXISTS #{table}")
                 return true
             rescue OCIError
                 return false
             end
         end
         
         # Schema methods
         
         def column_type(type, attributes)
             case type.name
             when 'String'
                 'VARCHAR2'
             when 'Spider::DataTypes::Text'
                 'CLOB'
             when 'Fixnum'
                 'NUMBER'
             when 'Float'
                 'FLOAT'
             when 'Date', 'DateTime'
                 'DATE'
             when 'Spider::DataTypes::Binary'
                 'BLOB'
             when 'Spider::DataTypes::Bool'
                 'NUMBER'
             end
         end
         
         def column_attributes(type, attributes)
             db_attributes = super(type, attributes)
             case type.name
             when 'String'
                 db_attributes[:length] = attributes[:length] || 255
             when 'Fixnum'
                 db_attributes[:precision] = attributes[:precision] || 38
                 db_attributes[:length] = nil
             when 'Float'
                 # FIXME
                 db_attributes[:precision] = attributes[:precision] if (attributes[:precision])
             when 'Spider::DataTypes::Bool'
                 db_attributes[:precision] = 1
                 db_attributes[:length] = nil
             end
             return db_attributes
         end
         
         def table_name(name)
             table_name = name.to_s.gsub('::', '_')
             return shorten_identifier(table_name, 30).upcase
         end
         
         def column_name(name)
             super.upcase
         end
         
         def sequence_name(name)
             shorten_identifier(name, 30).upcase
         end
         
         def schema_field_varchar2_equal?(current, field)
             # FIXME: can't find the length
             return true
         end
         
         def schema_field_number_equal?(current, field)
             # FIXME: where is the precision?
             return true
         end
         
        
    end
    
    class OCI8NilValue
        attr_accessor :type
        
        def initialize(type)
            @type = type
        end
        
        def to_s
            'NULL'
        end
        
    end
    
    ###############################
    #   Exceptions                #
    ###############################
    
    class OCI8Exception < RuntimeError
    end
    
end; end; end; end
