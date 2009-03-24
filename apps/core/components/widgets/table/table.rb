module Spider; module Components
    
    class Table < Spider::Widget
        tag 'table'
        i_attribute :model, :required => true
        is_attribute :elements, :process => lambda{ |v| v.split(',').map{ |v| v.strip.to_sym } }
        attribute :row_limit, :type => Fixnum, :default => 15
        attribute :paginate, :type => TrueClass, :default => true
        attr_accessor :queryset
        
        def prepare
            if (@attributes[:paginate])
                @page = params['page']
                @page ||= session[:page]
                @page ||= 1
                @page = @page.to_i
                @offset = ((@page - 1) * @attributes[:row_limit])
            end
            if params['sort']
                @sort = params['sort'].to_sym 
                @page = 1
            end
            if (@sort)
                if (@model.elements[@sort].model?)
                    s = []
                    @model.elements[@sort].model.each_element{ |el| s << "#{@sort}.#{el.name}" if el.type == String && !el.primary_key? }
                    @sort = s
                end
            end
            @sort = session[:sort] if !@sort && session[:sort]
            session[:sort] = @sort if @sort
            @sort = [@sort] if @sort && !@sort.is_a?(Array)
        end
        
        def execute
            @elements ||= @model.elements_array.map{ |el| el.name }
            @scene.sortable = {}
            @model.elements_array.each{ |el| @scene.sortable[el.name] = @model.mapper.mapped?(el) ? true : false }
            @scene.labels = {}
            @elements.each do |el|
                @scene.labels[el] = @model.elements[el].label
            end
            @rows = @queryset ? @queryset : @model.all
            if (@attributes[:paginate])
                @rows.limit = @attributes[:row_limit]
                @rows.offset = @offset
                @scene.page = @page
                @scene.paginate = true
            end
            @rows.order_by(*@sort) if @sort
            @rows.load
            @scene.rows = prepare_rows(@rows)
            @scene.has_more = @rows.has_more?
            @scene.pages = (@rows.total_rows.to_f / @attributes[:row_limit]).ceil
        end
        
        def prepare_rows(rows)
            res = []
            rows.each do |row|
                res_row = {}
                @elements.each do |el|
                    if (@model.elements[el].multiple?)
                        list = "<ul>"
                        row[el].load
                        row[el][0..2].each{ |sub|
                            sub_desc = sub.nil? ? '' : sub.to_s

                            list += "<li>"+sub_desc+"</li>" unless sub_desc.empty?
                        }
                        list += "<li>...</li>" if (row[el].total_rows > 3)
                        list += "</ul>"
                        res_row[el] = list
                    else
                        res_row[el] = row[el].to_s
                    end
                end
                debug("RES ROW:")
                debug(res_row)
                res << res_row
            end
            return res
        end
        
        
    end
    
end; end