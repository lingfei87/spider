require 'spiderfw/templates/template_blocks'

module Spider; module TemplateBlocks
    
    class Yield < Block
        
        def compile
            init = nil
            #c = "self[:yield_to][:controller].send(self[:yield_to][:action], *self[:yield_to][:arguments])\n"
            c = "yield :yield_to\n"
            return CompiledBlock.new(init, c)
        end
        
    end
    
    
end; end