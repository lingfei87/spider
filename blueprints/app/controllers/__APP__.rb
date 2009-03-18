<%= modules[0..-2].inject(""){ |s, mod| s+= "module #{mod}; "} %>module <%=modules[-1]%>
    
    class <%= module_name %>Controller < Spider::PageController
        include HTTP, StaticContent
        
        layout '<%= app_name %>'
    
        def index
            @scene.msg = 'Hello!'
            render('index')
        end
    
    end
    
<%= modules[0..-2].inject("") { |str, mod| str+= 'end; '} %>end