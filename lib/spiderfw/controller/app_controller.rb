require 'spiderfw/controller/mixins/static_content'

module Spider
    
    class AppController < Controller
        include Visual
        include StaticContent

        
    end
    
end