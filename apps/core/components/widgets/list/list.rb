module Spider; module Components
    
    class Menu < Spider::Widget
        tag 'list'
        
        is_attr_accessor :current
        attr_to_scene :sections
        
        def init
            @sections = {}
        end
        
        def add(section, label, target)
            @sections[section] ||= []
            @sections[section] << [label, target]
        end

    end
    
end; end