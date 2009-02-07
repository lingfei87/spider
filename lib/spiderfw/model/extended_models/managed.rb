require 'spiderfw/model/base_model'

module Spider; module Model
    
    class Managed < BaseModel
        element :id, Fixnum, {
            :primary_key => true, 
            :autoincrement => true, 
            :read_only => true, 
            :element_position => 0
        }
        
        # def id=(val)
        #     raise ModelException, "You can't assign a value to the 'id' element"
        # end
        
        def assign_id(val)
            @id = val
        end
        
        def self.managed?
            true
        end
        
    end
            
end; end