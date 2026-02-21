class BroadcastOrderUpdateJob < ApplicationJob
  queue_as :default

  def perform(order_id)
    order = Order.find_by(id: order_id)
    return unless order

    ActionCable.server.broadcast("order_#{order.id}", {
      id: order.id,
      status: order.status,
      eta_minutes: order.eta_minutes,
      queue_position: order.queue_position
    })
  end
end
