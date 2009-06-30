module Spider; module Messenger

    class MessengerController < Spider::PageController
        layout :spider_admin
        
        Messenger.queues.keys.each do |queue|
            route queue.to_s, self, :do => lambda{ |action| @queue = @dispatch_action }
        end

        def before(action='', *params)
            q = Messenger.queues[@queue.to_sym]
            raise NotFound(action) unless q
            @queue_model = q[:model]
            @scene.queue_model = @queue_model
            super
            @response.headers['Content-Type'] = 'text/html'
        end
        
        def execute(action='', *params)
            return super unless @queue
            # debugger
            # raise NotFound.new(action) unless @queue
            super
        end

        def index
            return list if (@queue)
            @scene.queues = []
            @scene.queue_info = {}
            Messenger.queues.each do |name, details|
                model = details[:model]
                @scene.queue_info[name] = {
                    :sent => model.sent.total_rows,
                    :queued => model.queued.total_rows,
                    :failed => model.failed.total_rows
                }
            end
            render 'index'
        end

        def queue
        end

        def failed
        end

        def sent
        end

        private

        def list(condition=nil)
            render 'list'
            # 
            # tmpl = init_template('list')
            # tmpl.init(@scene)
            # tmpl.exec
            # tmpl.render(@scene)
        end







    end


end; end