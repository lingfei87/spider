require 'spiderfw/model/type'

# The class representing a BaseModel element.

module Spider; module Model

    class Element
        attr_reader :name
        attr_accessor :attributes
        attr_accessor :definer_model

        def initialize(name, type, attributes={})
            @name = name
            @type = type
            @attributes = attributes
        end
        
        # The element type, as per the second argument passed to the Model::BaseModel.element method.
        # This may be different from #model.
        def type
            @type
        end
        
        # The actual model used to represent the association. Will return the #association_type or the #type.
        def model
            return nil unless model?
            return association_type || type
        end
        
        # True if the element model is a junction (for a many to many relationship).
        def junction?
            self.attributes[:junction]
        end
        
        # The model used for the association. The BaseModel will automatically create a junction model for 
        # many to many relationships, unless one is supplied with the :through attribute. This will be set
        # for n <-> n relationships, and will be nil otherwise.
        def association_type
            @association_type ||= self.attributes[:association_type]
        end
        
        # True if the element defines a 1|n -> n association.
        def multiple?
            self.attributes[:multiple]
        end
        
        # True if the element must have a value.
        def required?
            self.attributes[:required]
        end
        
        # True if no two model instances can have the same value for the element.
        def unique?
            self.attributes[:unique]
        end
        
        # True if the element defines an association to another model.
        def model?
            return @is_model if @is_model != nil
            @is_model = (type < Spider::Model::BaseModel || association_type)
        end
        
        # True if the element is integrated from another one. (See also BaseModel#integrate).
        # Example:
        #   class Address < BaseModel
        #     element :street, String
        #     element :area_code, String
        #   end
        #   class Person < BaseModel
        #     element :name, String
        #     element :address, Address
        #     integrate :address
        #   end
        #   Person.elements[:street].integrated? => true
        #   Person.elements[:street].integrated_from => :address
        #   Person.elements[:street].integrated_from_element => :street 
        def integrated?
            return @is_integrated if @is_integrated != nil
            @is_integrated = self.attributes[:integrated_from]
        end
        
        # If the element is integrated, the element from which it is taken. See also #integrated?.
        def integrated_from
            self.attributes[:integrated_from]
        end
        
        # If the element is integrated, the element corresponding to this in the model corresponding to
        # the #integrated_from element. See also #integrated?.
        def integrated_from_element
            self.attributes[:integrated_from_element]
        end
        
        # True if the element is a primary key.
        def primary_key?
            @primary_key ||= self.attributes[:primary_key]
        end
        
        # True if the element is read only.
        def read_only?
            self.attributes[:read_only]
        end
        
        # The reverse element in the relationship to another model.
        def reverse
            self.attributes[:reverse]
        end
        
        # True if the element has a reverse, and that reverse is not multiple
        def has_single_reverse?
            return true if self.attributes[:reverse] && !model.elements[self.attributes[:reverse]].multiple?
        end
        
        # True if the element model is an InlineModel
        def inline?
            self.attributes[:inline]
        end
        
        # True if the element type has been extended by passing a block to Model::BaseModel.element
        def extended?
            self.attributes[:extended]
        end
        
        # True if the :hidden attribute is set.        
        def hidden?
            self.attributes[:hidden]
        end
        
        # True if only the defining BaseModel holds references to the associated
        def owned?
            self.attributes[:owned]
        end
        
        def embedded?
            self.attributes[:embedded]
        end
        
        # True if the element is generated on save by the model or the mapper.
        def autogenerated?
            return (self.attributes[:auto] || self.attributes[:autoincrement])
        end
        
        # Named association.
        def association
            self.attributes[:association]
        end
        
        # Label. Will use the :label attribute, or return the name split by '_' with each word capitalized.
        def label
            prev_text_domain = nil
            if @definer_model && @definer_model != Spider::Model::Managed
                prev_text_domain = FastGettext.text_domain
                FastGettext.text_domain = @definer_model.app.short_name if FastGettext.translation_repositories.key?(@definer_model.app.short_name)
            end
            l = self.attributes[:label] ? _(self.attributes[:label]) : Inflector.underscore_to_upcasefirst(@name.to_s)
            if prev_text_domain
                FastGettext.text_domain = prev_text_domain
            end
            l
        end
        
        def to_s
            return "Element '#{@name.to_s}'"
        end
        
        # Storage for the element's #model.
        def storage
            return nil unless model?
            return self.mapper.storage
        end
        
        # Mapper for the element's #model.
        def mapper
            return nil unless model?
            return self.model.mapper
        end

        # The element's Condition, if any. If a condition is set with the :condition attribute,
        # the association to the element's model will be filtered by it.
        def condition
            cond = attributes[:condition]
            cond = Condition.new(cond) if (cond && !cond.is_a?(Condition))
            return cond
        end
        
        # Lazy attribute. (See #lazy_groups).
        def lazy
            attributes[:lazy]
        end
        
        # True if lazy attribute is set. (See #lazy_groups).
        def lazy?
            attributes[:lazy]
        end
        
        # Returns the lazy groups this elements is in, as set by BaseModel#element with the :lazy attributes.
        # Lazy groups are used by the mapper to determine which elements to autoload:
        # when an element in a lazy group is accessed, all the elements in the same group(s) will be loaded.
        def lazy_groups
            return nil unless attributes[:lazy] && attributes[:lazy] != true
            return attributes[:lazy].is_a?(Array) ? attributes[:lazy] : [attributes[:lazy]]
        end
        
        def clone
            self.class.new(@name, @type, self.attributes.clone)
        end
        
        # def queryset
        #     return nil unless model?
        #     set_model = self.attributes[:queryset_model] ? self.attributes[:queryset_model] : type
        #     set = QuerySet.new(set_model)
        #     set.query.condition = self.attributes[:condition] if self.attributes[:condition]
        #     if (self.attributes[:request])
        #         set.query.request = self.attributes[:request]
        #     else
        #         set_model.elements.each do |name, el|
        #             set.query.request[name] = true unless el.model?
        #         end
        #     end
        #     return set
        # end
        
        # # Clones the current model, detaching it from the original class and allowing to modify
        # # it (adding other elements)
        # def extend_model
        #     return if @extended_model
        #     @original_model = @type
        #     class_name = @type.name
        #     @type = Class.new(BaseModel)
        #     params = {}
        #     if (self.attributes[:association] == :multiple_choice)
        #         params[:hide_elements] = true
        #         params[:hide_integrated] = false
        #     else
        #         params[:hide_integrated] = true
        #     end
        #     @type.extend_model(@original_model, params)
        #     if (self.attributes[:model_name])
        #         new_name = @original_model.parent_module.name.to_s+'::'+self.attributes[:model_name].to_s
        #     else
        #         new_name = @original_model.name+'.'+@name.to_s
        #     end
        #     @type.instance_variable_set(:"@name", new_name)
        #     proxied_type = @original_model
        #     @type.instance_eval do
        #         def name
        #             @name
        #         end
        #         
        #         @proxied_type = proxied_type
        #         # def storage
        #         #     # it has only added elements, they will be merged in by the element owner
        #         #     require 'spiderfw/model/storage/null_storage'
        #         #     return Spider::Model::Storage::NullStorage.new
        #         # end
        #         def mapper
        #             require 'spiderfw/model/mappers/proxy_mapper'
        #             return @mapper ||= Spider::Model::Mappers::ProxyMapper.new(self, @proxied_type)
        #         end
        #     end
        #     @extended_model = true
        # end

    end

end; end
