module Admin
  class OrdersController < BaseController
    before_action :set_order

    def start_production
      authorize :admin_order, :transition?
      Orders::TransitionService.new(order: @order, actor: current_admin, reason: params[:reason]).start_production
      respond_success
    rescue Orders::TransitionService::InvalidTransition => e
      respond_error(e.message)
    end

    def finish
      authorize :admin_order, :transition?
      Orders::TransitionService.new(order: @order, actor: current_admin).finish
      respond_success
    rescue Orders::TransitionService::InvalidTransition => e
      respond_error(e.message)
    end

    def mark_ready
      finish
    end

    def mark_delivered
      authorize :admin_order, :transition?
      Orders::TransitionService.new(order: @order, actor: current_admin).mark_delivered
      respond_success
    rescue Orders::TransitionService::InvalidTransition => e
      respond_error(e.message)
    end

    private

    def set_order
      @order = Order.find(params[:id])
    end

    def respond_success
      respond_to do |format|
        format.html { redirect_back fallback_location: admin_queue_path, notice: "Pedido atualizado." }
        format.json { render json: @order.reload }
      end
    end

    def respond_error(message)
      respond_to do |format|
        format.html { redirect_back fallback_location: admin_queue_path, alert: message }
        format.json { render json: { error: message }, status: :conflict }
      end
    end
  end
end
