class BroadcastQueueUpdateJob < ApplicationJob
  queue_as :default

  def perform
    payload = Order.open_queue.limit(100).pluck(:id, :status, :queue_position, :eta_minutes).map do |id, status, queue_position, eta_minutes|
      { id: id, status: status, queue_position: queue_position, eta_minutes: eta_minutes }
    end

    ActionCable.server.broadcast("orders_queue", { payload: payload })
  end
end
