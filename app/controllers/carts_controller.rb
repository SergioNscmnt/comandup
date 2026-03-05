class CartsController < ApplicationController
  def show
    load_cart_state
  end

  def delivery_quote
    quote = Orders::DeliveryQuoteService.call(
      cep: params[:cep],
      subtotal_cents: params[:subtotal_cents]
    )
    render json: quote
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue StandardError
    render json: { error: "Não foi possível calcular a taxa de entrega agora." }, status: :service_unavailable
  end

  def checkout_preview
    pricing = Orders::CheckoutPricingService.call(
      customer: current_customer,
      items: cart_items_payload,
      order_type: preview_order_type,
      coupon_code: params[:coupon_code],
      delivery_cep: params[:delivery_cep]
    )

    render json: {
      subtotal_cents: pricing[:subtotal_cents],
      discount_cents: pricing[:discount_cents],
      delivery_fee_cents: pricing[:delivery_fee_cents],
      total_cents: pricing[:total_cents],
      delivery_distance_km: pricing[:delivery_distance_km],
      promotion_applied: pricing[:promotion_applied],
      promotion_name: pricing[:promotion_name],
      free_shipping: pricing[:free_shipping],
      minimum_delivery_order_cents: pricing[:minimum_delivery_order_cents]
    }
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue StandardError
    render json: { error: "Não foi possível atualizar o resumo do pedido agora." }, status: :service_unavailable
  end

  def update
    product = Product.find_by(id: params[:product_id])
    unless product
      redirect_back fallback_location: products_path, alert: "Produto não encontrado"
      return
    end

    current = cart_entry(product.id)
    quantity = current["quantity"].to_i

    case params[:operation]
    when "add"
      note = params[:note].presence
      increment = params[:quantity].to_i
      increment = 1 if increment <= 0
      set_cart_entry(product.id, quantity: quantity + increment, note: note)
      @added_quantity = increment
    when "decrease"
      new_quantity = quantity - 1
      set_cart_entry(product.id, quantity: new_quantity)
    when "remove"
      set_cart_entry(product.id, quantity: 0)
    when "note"
      set_cart_entry(product.id, quantity: quantity, note: params[:note])
    end

    if params[:operation] == "add"
      @toast_message = @added_quantity.to_i > 1 ? "Itens adicionados ao carrinho" : "Item adicionado ao carrinho"
    end

    respond_to do |format|
      format.turbo_stream do
        load_cart_state
        @categories = Category.ordered
        @selected_category_id = params[:category_id].presence&.to_i

        @products = Product.where(active: true).includes(:category)
        @products = @products.where(category_id: @selected_category_id) if @selected_category_id.present?
        @products = @products.order(:name)
        load_catalog_mental_triggers(products_scope: @products)
      end
      format.html { redirect_back fallback_location: cart_path }
    end
  end

  def destroy
    clear_cart!
    redirect_to cart_path, notice: "Carrinho limpo"
  end

  private

  def preview_order_type
    return :table if table_session_active?

    value = params[:order_type].to_s.downcase
    return :pickup unless Order.order_types.key?(value)

    value.to_sym
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

  def load_cart_state
    @items = cart_items
    @subtotal_cents = @items.sum { |item| item[:total_cents] }
  end

  def cart_items
    products = Product.where(id: cart_storage.keys).index_by { |p| p.id.to_s }

    cart_storage.filter_map do |product_id, quantity|
      product = products[product_id]
      next unless product

      if quantity.is_a?(Hash)
        qty = quantity["quantity"].to_i
        note = quantity["note"].to_s
      else
        qty = quantity.to_i
        note = ""
      end
      next if qty <= 0

      {
        product: product,
        quantity: qty,
        note: note,
        unit_cents: product.price_cents,
        total_cents: product.price_cents * qty
      }
    end
  end
end
