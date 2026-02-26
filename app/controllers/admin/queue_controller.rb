module Admin
  class QueueController < BaseController
    def show
      authorize :admin_order, :queue?

      @filter = params[:order_type].presence
      @orders = Order.open_queue.includes(:customer, order_items: [:product, :combo])
      @orders = @orders.where(order_type: Order.order_types[@filter]) if @filter && Order.order_types.key?(@filter)
      @next_order_id = Order.open_queue.first&.id

      respond_to do |format|
        format.html
        format.json { render json: @orders }
      end
    end
  end
end
