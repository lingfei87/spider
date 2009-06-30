require 'apps/messenger/models/email'

module Spider
    
    module Messenger
        
        def self.queues
            {
                :email => {:model => Email}
            }
        end
                
        def self.process_queue(queue)
            @mutex ||= Mutex.new
            return if @mutex.locked?
            raise ArgumentError, "Queue #{name} not found" unless self.queues[queue]
            model = self.queues[queue][:model]
            @mutex.synchronize do
                now = DateTime.now
                list = model.where{ 
                    (sent == nil) &
                    ((send_from == nil) | (send_from <= now ) ) &
                    (next_try <= now)
                }
                list.each do |msg|
                    res = false
                    exc = nil
                    begin
                        res = self.send(:"send_#{queue}", msg)
                    rescue => exc
                    end
                    if (res)
                        msg.sent = now
                        msg.next_try = nil
                        msg.save
                    else
                        msg.last_try = now
                        msg.failed ||= 0
                        msg.failed += 1
                        if (exc)
                            msg.last_error = exc.to_s
                        else
                            msg.last_error = res
                        end
                        if (msg.failed >= Spider.conf.get("messenger.#{queue}.retries"))
                            msg.next_try = nil
                        else
                            msg.next_try = msg.last_try.to_local_time + (msg.failed * Spider.conf.get("messenger.#{queue}.retry_time") * 60)
                        end
                        msg.save
                    end
                            
                end
            end
        end
        
        def self.email(from, to, headers, body, params={})
            if (headers.is_a?(Hash))
                headers = headers.inject(""){ |h, p| h += "#{p[0]}: #{p[1]}\n"}
            elsif(headers.is_a?(Array))
                headers = headers.join("\n")
            end
            headers = "To: #{to}\n"+headers unless headers =~ /^To/
            headers = "From: #{from}\n"+headers unless headers =~ /^From/
            msg = Email.new(
                :from => from, :to => to, :headers => headers, :body => body, 
                :send_from => params[:send_from]
            )
            msg.next_try = DateTime.now
            msg.save
            return msg
        end
        
        def self.send_email(msg)
            require 'net/smtp'
            res = false
            Net::SMTP.start(
              Spider.conf.get('messenger.smtp.address'),
              Spider.conf.get('messenger.smpt.port'),
              Spider.conf.get('messenger.smtp.domain'),
              Spider.conf.get('messenger.smtp.username'),
              Spider.conf.get('messenger.smtp.password'),
              Spider.conf.get('messenger.smtp.auth_scheme')
            ) do |smtp|
                msg_str = msg.headers+"\n"+msg.body
                res = smtp.send_message msg_str, msg.from, msg.to
            end
            return res
        end
        
    end
    
end