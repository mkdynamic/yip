module Yip module Routers module WebSocket extend self
  extend Yis::WebSocket::RouteMatchers

  def process(msg, sys)
    case msg
    when m(:connect)
      puts "connect #{msg}"
      msg
    when m(:disconnect)
      puts "disconnect #{msg}"
      msg
    when m(:receive)
      puts "receive #{msg}"
      msg
    when m(:transmit)
      puts "transmit #{msg}"
      msg
    when m(:join)
      puts "join #{msg}"
      msg
    when m(:leave)
      puts "leave #{msg}"
      msg
    else msg
    end
  end
end end end

#   def open(socket, sys)
#   end

#   def close(socket, sys)
#   end

#   "/channel/topic"

#   def receive(message, socket, sys)
#     case message['op']
#     when 'create_typer'
#       message = message.update_in('data', 'typer', 'client') { socket.client }
#       MessageBus.publish(sys[:redis], message[:channel], Hamster.to_ruby(message))
#     end
#   end

#   def transmit(message, socket, sys)
#     socket.send_data(JSON.dump(Hamster.to_ruby(message)))
#   end
# end end


#         .update_in(:res, &add_cookies(channel: "test", client: SecureRandom.hex(3)))
