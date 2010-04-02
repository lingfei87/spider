require 'apps/core/auth/_init.rb'

module Spider; module Components
    
    # This widget creates an administration page for models.
    #
    # Attributes:
    # *:models*     Comma-separated list of model names
    # *:title*
    # *:logout_url* 
    #
    # Content:
    # Takes the tags
    # *admin:model*     A model to administer
    # *admin:app*       Administer all models belonging to the app. Can have an 'except' attribute.
    
    class Admin < Spider::Widget
        tag 'admin'
        
        i_attribute :models, :process => lambda{ |models| models.split(/,[\s\n]*/).map{|m| const_get_full(m) } }
        is_attr_accessor :title, :default => lambda{ _("Administration") }
        is_attr_accessor :logout_url, :default => Spider::Auth.request_url+'/login/logout'
        
        def init
            @items = []
        end
        
        def route_widget
            [:switcher, @_action]
        end
        
        def prepare_widgets
            @models.each do |model|
                crud = Crud.new(@request, @response)
                crud.id = model.name.to_s.gsub('::', '_').downcase
                crud.model = model
                @widgets[:switcher].add(model.label_plural, crud, 'Gestione Dati')
            end
            if (@request.respond_to?(:user) && @request.user)
                @scene.username = @request.user.to_s
            else
                @scene.username = _("guest")
                @scene.guest = true
            end
            super
        end
        
        def run
            @scene.current = @widgets[:switcher].current_label
            super
        end
        
        def parse_runtime_content(doc, src_path)
            doc = super
            mods = []
            doc.search('admin:model').each do |mod|
                mods << const_get_full(mod.innerText)
            end
            doc.search('admin:app').each do |app_tag|
                except = []
                if (app_tag.attributes['except'])
                    except = app_tag.attributes['except'].split(',').map{ |e| e.strip }
                end
                app = const_get_full(app_tag.innerText.strip)
                mods += app.models.select{ |m|
                    !m.attributes[:sub_model] && m.mapper.class.write? && !except.include?(m.name.split('::')[-1])
                }.sort{ |a, b| a.name <=> b.name }
            end
            @models ||= []
            @models += mods
            return doc
        end

    end
    
end; end
