require 'spiderfw/controller/controller_io'
require 'spiderfw/controller/request'
require 'spiderfw/controller/response'
require 'spiderfw/controller/scene'
require 'spiderfw/templates/visual'
require 'spiderfw/controller/controller_exceptions'
require 'spiderfw/controller/first_responder'
require 'spiderfw/widget/widget'

require 'spiderfw/controller/helpers/http'
require 'spiderfw/controller/helpers/static_content'

module Spider
    
    class Controller
        include Dispatcher
        include Logger
        include Helpers
        
        class << self

            def default_action
                'index'
            end
            
            def app
                @app ||= self.parent_module
            end
            
            def template_path
                return self.app.path+'/templates'
            end
            
            def layout_path
                return self.app.path+'/layouts'
            end
            
            def check_action(action, check)
                checks = check.is_a?(Array) ? check : [check]
                action = action.to_s
                action = default_action if action == ''
                action = action[0..-1] if action[-1].chr == '/'
                checks.each do |check|
                    return true if check.is_a?(String) && action == check || (action[-1].chr == '/' && action[0..-2] == check)
                    return true if check.is_a?(Regexp) && action =~ check
                end
                return false
            end      
            
        end
        
        attr_reader :request, :response
        attr_reader :action
        
        def initialize(request, response, scene=nil)
            @request = request
            @response = response
            @scene = scene || Scene.new
            @dispatch_path = ''
            init
            #@parent = parent
        end
        
        # Override this for controller initialization
        def init
            
        end
        
        def inspect
            self.class.to_s
        end
        
        def dispatch_prefix
            @request.action[0..@request.action.index(@action)-1].gsub(/\/+$/, '')
        end
        
        
        def execute(action='', *arguments)
            return if @done
            debug("Controller #{self} executing #{action} with arguments")
            debug(arguments)
            @call_path = action
            # before(action, *arguments)
            # do_dispatch(:before, action, *arguments)
            catch(:done) do
                begin
                    action = self.class.default_action if (action == '')
                    method = action
                    additional_arguments = []
                    if (action =~ /^([^:]+)(:.+)$/)
                        method = $1
                    elsif (action =~ /^([^\/]+)\/(.+)$/) # methods followed by a slash
                        method = $1
                        additional_arguments = [$2]
                    end
                    if (self.class.method_defined?(method.to_sym))
                        debug("SENDING #{method} WITH ARGS:")
                        debug(arguments+additional_arguments)
                        send(method, *(arguments+additional_arguments))
                    elsif (can_dispatch?(:execute, action))
                        #run_chain(:execute, action, *arguments)
                        do_dispatch(:execute, action)
#                        after(action, *arguments)
                    else
                        raise NotFound.new(action)
                    end
                rescue => exc
                    debug("CONTROLLER TRY_RESCUE #{exc}")
                    try_rescue(exc)
                end
            end
        end
        
        def before(action='', *arguments)
            catch(:done) do
                begin
                    debug("IN BEFORE; I AM #{self}")
                    # begin
                    #     run_chain(:before)
                    #     #return dispatch(:before, action, *arguments)
                    # rescue => exc
                    #     try_rescue(exc)
                    # end
                    do_dispatch(:before, action, *arguments)
                rescue => exc
                    try_rescue(exc)
                end
            end
        end
                

        
        def after(action='', *arguments)
            catch(:done) do
                begin
                    do_dispatch(:after, action, *arguments)
                rescue => exc
                    try_rescue(exc)
                end
            end
            # begin
            #     run_chain(:after)
            #     #dispatch(:after, action, params)
            # rescue => exc
            #     try_rescue(exc)
            # end
        end
        
        def done
            self.done = true
            throw :done
        end
        
        def done=(val)
            @done = val
            @dispatch_previous.done = val if @dispatch_previous
        end

        
        protected

        def dispatched_object(route)
            klass = route.dest
            return klass if klass.class != Class
            obj = klass.new(@request, @response, @scene)
#            obj.dispatch_path = @dispatch_path + route.path
            return obj
        end
        


        
        def try_rescue(exc)
            raise exc
        end
        
        
        private
        
        def pass
            action = @call_path
            return false unless can_dispatch?(:execute, action)
            debug("CAN DISPATCH #{action}")
            do_dispatch(:execute, action)
            return true
        end

        
    end
    
    
end

