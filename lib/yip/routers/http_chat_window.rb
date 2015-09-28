module Yip module Routers module HttpChatWindow extend self
  extend Yis::Http::Renderers

  def process(req, sys)
    # channel = req.fetch(:headers).fetch(:cookies).get('channel')
    # client = req.fetch(:headers).fetch(:cookies).get('client')

    data = req[:params]
      .update_in('message', 'id') { SecureRandom.hex(16) }

    msg = Yis::WebSocket::Msg.build(
      type: :transmit,
      channel: "chat",
      topic: "create_message",
      data: data)

    req
      .update_in(:res, &render_json(ok: true))
      .update_in(:outbox) { |msgs| msgs.push(msg) }
  end
end end end
