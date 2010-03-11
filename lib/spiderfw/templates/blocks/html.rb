require 'spiderfw/templates/template_blocks'

module Spider; module TemplateBlocks
    
    class HTML < Block
        
        def compile(options={})
            c = ""
            init = ""
            start = get_start(options)
            c += "$out << '#{start}'\n"
            is_root = options[:root]
            options.delete(:root)
            c += "unless self[:widget][:target_only] && !self[:widget][:is_target]\n" if (options[:mode] == :widget && is_root)
            c, init = compile_content(c, init, options)
            c += "end\n"  if (options[:mode] == :widget && is_root)
            end_tag = get_end
            c += "$out << '#{end_tag}'\n" if end_tag
            return CompiledBlock.new(init, c)
        end
        
        def get_start(options)
            if options[:mode] == :widget
                cl = @el.get_attribute('class') || ''
                if @el.has_attribute?('id')
                    cl += ' ' unless cl.empty?
                    cl += "id-#{@el.get_attribute('id')}"
                    @el.remove_attribute('id')
                end
                if (options[:root])
                    cl += " widget"
                    if options[:owner_class]
                        cl += " wdgt-#{options[:owner_class].name.gsub('::', '-')}"
                    end
                    @el.set_attribute('id', "{ @widget[:full_id] }")
                    cl += ' ' unless cl.empty?
                    cl += '{ @widget[:css_classes] }'
                end
                @el.set_attribute('class', cl)
            end
            start = "<"+@el.name
            @el.attributes.to_hash.each do |key, val|
                start += " #{key}=\""
                rest = scan_vars(val) do |text, code|
                    start += text+"'+("+vars_to_scene(code)+").to_s+'"
                end
                start += rest
#                start += replace_vars(val)
                # if (val =~ /(.*)\{ (.+) \}(.*)/)
                #     start += $1+"'+"+var_to_scene($2)+".to_s+'"+$3
                # else
                #     start += val
                # end
                start += '"'
            end
            #start += " /" unless @el.etag
            start += ">"
            return start
        end
        
        def get_end
            str = escape_text(@el.etag.inspect) if @el.etag
            str = str[1..-2] if str && str[0].chr == '"' # FIXME:  This is a workaround Hpricot 0.6 and 0.8 differences
            return str
        end
        
    end
    
    
end; end