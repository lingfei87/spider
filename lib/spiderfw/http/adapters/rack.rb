require 'spiderfw/controller/request'

module Spider; module HTTP
    
    class RackRequest < Spider::Request
        attr_accessor :rack_input
        
        
        def body(&proc)
            @rack_input.each{ |buf| yield buf }
        end
        
        
    end
    
    class RackIO < ControllerIO

        def initialize(response, controller_response, w)
            @response = response
            @controller_response = controller_response
            @w = w
            @headers_sent = false
            @rack_thread = Thread.current
        end

        def write(msg)
            send_headers unless @headers_sent
            @w.write(msg)
        end

        def send_headers
            Spider::Logger.debug("---SENDING HEADERS----")
            @controller_response.prepare_headers
            @response[:status] = @controller_response.status
            @response[:headers] = {}
            @controller_response.headers.each do |key, val|
                if (val.is_a?(Array))
                    val.each{ |v| @response[:headers][key] = v.to_s }
                else
                    @response[:headers][key] = val.to_s
                end
            end
            @headers_sent = true
            @rack_thread.run
        end

        def headers_sent?
            @headers_sent
        end
        
        def set_body_io(io)
            return super if headers_sent?
            @response.body = io
            send_headers
        end


        def flush
        end

    end
    
    class RackApplication

        def call(env)
            env = prepare_env(env)
            controller_request = RackRequest.new(env)
            controller_request.server = RackApplication
            controller_request.rack_input = env['rack.input']
            path = env['PATH_INFO'].chomp('/')
            controller_request.action = path
            controller_request.request_time = DateTime.now

            r, w = IO.pipe
            rack_response_hash = {:body => r}

            controller_response = Spider::Response.new
            controller_response.server_output = RackIO.new(rack_response_hash, controller_response, w)


            controller_done = false

            controllerThread = Thread.start do
                begin
                    controller = ::Spider::HTTPController.new(controller_request, controller_response)
                    controller.extend(Spider::FirstResponder)
                    controller.before(path)
                    controller.execute(path)
                    controller.after(path)
                    Spider::Logger.debug("Controller done")
                rescue => exc
                    Spider.logger.debug("Error:")
                    Spider.logger.debug(exc)
                    controller.ensure() if controller
                ensure
                    controller_response.server_output.send_headers unless controller_response.server_output.headers_sent?
                    w.close
                    controller_done = true
                end
            end

            while (!controller_done && !controller_response.server_output.headers_sent?)
                Thread.stop
            end
            Spider.logger.debug("Rack responding")
            return [rack_response_hash[:status], rack_response_hash[:headers], rack_response_hash[:body]]
        end
        
        def prepare_env(env)
            env['HTTP_CONTENT_TYPE'] = env['CONTENT_TYPE']
            return env
        end
        
    end
    
end; end
    