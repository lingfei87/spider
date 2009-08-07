module Spider; module Components
    
    class Menu < Spider::Widget
        tag 'menu'
        
        i_attribute :model, :required => :datasource
        i_attribute :queryset, :required => :datasource
        
        rest_model :queryset, :verbs => ['GET']
        
        def init
            @sections = {}
        end
        
        def add(section, label, target)
            @sections[section] ||= []
            @sections[section] << [label, target]
        end

    end
    
end; end