class CartsController < ApplicationController
  def show
    @items = cart_items
    @subtotal_cents = @items.sum { |item| item[:total_cents] }
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
      set_cart_entry(product.id, quantity: quantity + 1, note: note)
    when "decrease"
      new_quantity = quantity - 1
      set_cart_entry(product.id, quantity: new_quantity)
    when "remove"
      set_cart_entry(product.id, quantity: 0)
    when "note"
      set_cart_entry(product.id, quantity: quantity, note: params[:note])
    end

    redirect_back fallback_location: cart_path
  end

  def destroy
    clear_cart!
    redirect_to cart_path, notice: "Carrinho limpo"
  end

  private

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
