class OrdersController < ApplicationController
  skip_forgery_protection
  before_action :authenticate_customer!, only: :index

  def index
    @orders = current_customer.orders.for_customer_channel.order(created_at: :desc).limit(30)
  end

  def create
    items = order_params.fetch(:items, [])
    items = cart_items_payload if items.blank?

    order_type = normalized_order_type
    return unless ensure_checkout_access!(order_type)

    order = Orders::CreateService.new(
      customer: current_customer,
      items: items,
      order_type: order_type,
      table_number: params[:table_number],
      delivery_address: params[:delivery_address]
    ).call
    authorize order, :create?

    if Rails.configuration.x.order_settings.modo_pagamento == "POS_PAGO"
      Orders::TransitionService.new(order: order, actor: current_customer, reason: "pos_pago_auto").confirm_received
    end

    store_order_token(order)
    clear_cart! if params[:items].blank?

    respond_to do |format|
      format.html { redirect_to order_path(order), notice: "Pedido criado com sucesso" }
      format.json { render json: order, status: :created }
    end
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    respond_to do |format|
      format.html { redirect_to cart_path, alert: e.message }
      format.json { render json: { error: e.message }, status: :unprocessable_entity }
    end
  end

  def show
    @order = Order.find(params[:id])
    authorize @order, :show?

    respond_to do |format|
      format.html
      format.json { render json: @order.as_json(include: :order_items) }
    end
  end

  def cancel
    order = Order.find(params[:id])
    authorize order, :cancel?

    Orders::TransitionService.new(order: order, actor: current_customer, reason: params[:reason]).cancel_by_customer
    render json: order.reload
  rescue Orders::TransitionService::InvalidTransition => e
    render json: { error: e.message }, status: :conflict
  end

  private

  def order_params
    params.permit(:order_type, :table_number, :delivery_address, items: [:product_id, :combo_id, :quantity, :notes])
  end

  def cart_items_payload
    session.fetch(:cart, {}).map do |product_id, entry|
      if entry.is_a?(Hash)
        { product_id: product_id.to_i, quantity: entry["quantity"].to_i, notes: entry["note"] }
      else
        { product_id: product_id.to_i, quantity: entry.to_i }
      end
    end
  end

  def normalized_order_type
    value = order_params[:order_type].presence || "table"
    value = value.to_s.downcase
    return :table unless Order.order_types.key?(value)

    value.to_sym
  end

  def ensure_checkout_access!(order_type)
    return true if order_type == :table
    return true if current_customer

    session[:return_to] = cart_path
    redirect_to customer_login_path, alert: "Entrar com Google para continuar."
    false
  end
end
