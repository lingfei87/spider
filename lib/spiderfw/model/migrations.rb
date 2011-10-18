require 'spiderfw/model/migrations/migration'
require 'spiderfw/model/migrations/irreversible_migration'
require 'spiderfw/model/migrations/replace'
require 'spiderfw/model/migrations/drop_element'

module Spider
    
    module Migrations
        
        def self.replace(model, element, values)
            Spider::Migrations::Replace.new(model, element, values)
        end

        def self.drop_element!(model, element, options={})
        	Spider::Migrations::DropElement.new(model, element, options={})
        end
        
        
    end
    
end