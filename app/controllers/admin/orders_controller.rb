module Admin
  class OrdersController < BaseController
    before_action :set_order
    before_action :ensure_table_order!, only: [:show, :checkout, :menu, :add_menu_item, :close_table]
    before_action :load_menu_catalog, only: [:menu]

    PAYMENT_METHODS = [
      { key: "credit", label: "Crédito", icon: :credit_card },
      { key: "debit", label: "Débito", icon: :credit_card_2 },
      { key: "pix", label: "Pix", icon: :qr },
      { key: "cash", label: "Dinheiro", icon: :cash }
    ].freeze

    def show
      authorize :admin_order, :show?
      @payment_methods = PAYMENT_METHODS
    end

    def checkout
      authorize :admin_order, :checkout?
      @payment_methods = PAYMENT_METHODS
    end

    def menu
      authorize :admin_order, :show?
    end

    def add_menu_item
      authorize :admin_order, :show?

      product = Product.find_by(id: params[:product_id], active: true)
      return redirect_to(menu_admin_order_path(@order), alert: "Item não encontrado no catálogo.") if product.blank?

      @order.add_product_to_table!(product)

      redirect_to menu_admin_order_path(@order, category_id: params[:category_id].presence, q: params[:q].to_s.strip.presence),
                  notice: "#{product.name} adicionado à #{@order.human_table_label.downcase}."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to menu_admin_order_path(@order, category_id: params[:category_id].presence, q: params[:q].to_s.strip.presence),
                  alert: e.record.errors.full_messages.to_sentence
    end

    def close_table
      authorize :admin_order, :checkout?

      unless @order.table_checkout_ready?
        return redirect_to checkout_admin_order_path(@order), alert: "A mesa ainda possui itens em preparo."
      end

      payment_method = permitted_checkout_params[:payment_method].presence_in(PAYMENT_METHODS.map { |method| method[:key] }) || PAYMENT_METHODS.first[:key]

      ActiveRecord::Base.transaction do
        @order.table_checkout_orders.each do |table_order|
          table_order.payments.create!(
            status: :approved,
            amount_cents: table_order.total_cents,
            provider: "admin_settlement",
            provider_reference: payment_method
          )
          Orders::TransitionService.new(order: table_order, actor: current_admin, reason: "checkout_#{payment_method}").mark_delivered
        end
      end

      redirect_to admin_dashboard_path(table_state: "occupied"), notice: "#{@order.human_table_label} liberada com sucesso."
    rescue Orders::TransitionService::InvalidTransition => e
      redirect_to checkout_admin_order_path(@order), alert: e.message
    end

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

    def ensure_table_order!
      return if @order.order_type_table?

      redirect_to admin_queue_path, alert: "Esse fluxo é exclusivo para mesas."
    end

    def permitted_checkout_params
      params.fetch(:checkout, {}).permit(:payment_method)
    end

    def load_menu_catalog
      @menu_categories = Category.ordered.to_a
      @selected_menu_category_id = params[:category_id].to_i if params[:category_id].present?
      @menu_query = params[:q].to_s.strip

      @menu_products = Product.includes(:category).where(active: true)
      @menu_products = @menu_products.where(category_id: @selected_menu_category_id) if @selected_menu_category_id.to_i.positive?
      if @menu_query.present?
        query = "%#{@menu_query.downcase}%"
        @menu_products = @menu_products.where("LOWER(products.name) LIKE ? OR LOWER(COALESCE(products.description, '')) LIKE ?", query, query)
      end
      @menu_products = @menu_products.order(:category_id, :name)
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
