class OrderChannel < ApplicationCable::Channel
  def subscribed
    order_id = params[:order_id].to_i
    reject unless order_id.positive?

    stream_from "order_#{order_id}"
  end
end
