module Yip module MessageBus extend self
  def subscribe(redis, channel_name, &blk)
    redis.subscribe("message_bus:#{channel_name}") do |on|
      on.message do |channel, msg|
        blk.call(JSON.load(msg))
      end
    end
  end

  def unsubscribe(redis, channel_name)
    redis.unsubscribe("message_bus:#{channel_name}")
  end

  def publish(redis, channel_name, message)
    redis.publish("message_bus:#{channel_name}", JSON.dump(message))
  end
end end
