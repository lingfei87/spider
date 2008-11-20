require 'spiderfw/model/storage/db/db_storage'
require 'rubygems'
require 'sqlite3'

module Spider; module Model; module Storage; module Db
    
    class SQLite < DbStorage
        
        @reserved_keywords = superclass.reserved_keywords + []
        class << self; attr_reader :reserved_kewords; end
        
        def parse_url(url)
            if (url =~ /(.+?):\/\/(.+)/)
                @file = $2
                @file = Spider.paths[:root] + '/' + @file[2..-1] if (@file[0..1] == './')
            else
                raise SQLiteException, "SQLite url '#{url}' is invalid"
            end
        end
        
         def connect()
            debug("sqlite opening file #{@file}")
            @db = SQLite3::Database.new(@file)
            @db.results_as_hash = true
        end
        
        def connected?
            @db != nil
        end
        
        def disconnect
            debug("sqlite closing file #{@file}")
            @db.close
            @db = nil
        end
        
        def prepare_value(type, value)
             case type
             when 'binary'
                 return SQLite3::Blob.new(value)
             end
             return value
         end
         
         def query(query)
             @last_query = query
             super
         end


         def execute(sql, *bind_vars)
             connect unless connected?
             if (bind_vars && bind_vars.length > 0)
                 debug_vars = bind_vars.map{|var| var && var.length > 50 ? var[0..50]+"...(#{var.length-50} chars more)" : var}.join(', ')
             end
             debug("sqlite executing:\n#{sql}\n[#{debug_vars}]")

             result = @db.execute(sql, *bind_vars)
             result.extend(StorageResult)
             @last_result = result
             if block_given?
                 result.each{ |row| yield row }
                 disconnect
             else
                 disconnect
                 return result
             end
         end
         

         def prepare(sql)
             debug("sqlite preparing: #{sql}")
             connect unless connected?
             return @db.prepare(sql)
         end

         def execute_statement(stmt, *bind_vars)
             stmt.execute(bind_vars)
         end
         
         def total_rows
             return nil unless @last_query
             q = @last_query
             unless (q[:offset] || q[:limit])
                 return @last_result ? @last_result.length : nil
             end
             q[:offset] = q[:limit] = nil
             q[:keys] = ["COUNT(*) AS N"]
             res = execute(sql_select(q), q[:bind_vars])
             return res[0]['N']
         end
         
         ##############################################################
         #   Methods to get information from the db                   #
         ##############################################################

         def list_tables
             return execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name").flatten
         end

         def describe_table(table)
             columns = {}
             stmt = prepare("select * from #{table}")
             stmt.columns.each_index do |index|
                 field = stmt.columns[index]
                 columns[field] ||= {}
                 if (stmt.types[index] =~ /([^\(]+)(?:\((\d+)\))?/)
                     columns[field][:type] = $1
                     columns[field][:length] = $2.to_i if $2
                 end
             end
             stmt.close
             return columns
         end

         def table_exists?(table)
             begin
                 stmt = prepare("select * from #{table}")
                 stmt.close
                 return true
             rescue SQLite3::SQLException
                 return false
             end
         end
         
        
    end
    
    ###############################
    #   Exceptions                #
    ###############################
    
    class SQLiteException < RuntimeError
    end
    
end; end; end; end