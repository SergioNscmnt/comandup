class ApplicationController < ActionController::Base
  include Pundit::Authorization

  rescue_from Pundit::NotAuthorizedError, with: :forbidden
  helper_method :current_admin, :current_customer, :current_user, :cart_count, :cart_total_cents

  private

  def current_admin
    @current_admin ||= User.admin.find_by(id: session[:admin_user_id]) if session[:admin_user_id].present?
  end

  def current_customer
    @current_customer ||= begin
      by_session = User.customer.find_by(id: session[:customer_user_id]) if session[:customer_user_id].present?
      requested_id = request.headers["X-Customer-Id"]
      by_header = User.customer.find_by(id: requested_id) if requested_id.present?
      by_session || by_header
    end
  end

  def current_user
    current_admin || current_customer
  end

  def pundit_user
    {
      user: current_user,
      guest_order_tokens: session[:guest_order_tokens] || {}
    }
  end

  def authenticate_customer!
    return if current_customer

    session[:return_to] = request.fullpath if request.get?
    redirect_to customer_login_path, alert: "Entre com Google para continuar."
  end

  def cart_storage
    session[:cart] ||= {}
  end

  def cart_entry(product_id)
    entry = cart_storage[product_id.to_s]
    case entry
    when Hash
      { "quantity" => entry["quantity"].to_i, "note" => entry["note"].to_s }
    else
      { "quantity" => entry.to_i, "note" => "" }
    end
  end

  def set_cart_entry(product_id, quantity:, note: nil)
    key = product_id.to_s
    return cart_storage.delete(key) if quantity <= 0

    existing_note = cart_entry(product_id)["note"]
    cart_storage[key] = { "quantity" => quantity, "note" => (note.nil? ? existing_note : note.to_s.strip) }
  end

  def cart_count
    cart_storage.sum do |_, entry|
      entry.is_a?(Hash) ? entry["quantity"].to_i : entry.to_i
    end
  end

  def cart_total_cents
    products = Product.where(id: cart_storage.keys).index_by { |product| product.id.to_s }

    cart_storage.sum do |product_id, quantity|
      product = products[product_id]
      amount = quantity.is_a?(Hash) ? quantity["quantity"].to_i : quantity.to_i
      product ? product.price_cents * amount : 0
    end
  end

  def clear_cart!
    session[:cart] = {}
  end

  def require_admin!
    raise Pundit::NotAuthorizedError unless current_admin
  end

  def store_order_token(order)
    return if order.service_token.blank?

    session[:guest_order_tokens] ||= {}
    session[:guest_order_tokens][order.id.to_s] = order.service_token
  end

  def has_guest_token_for?(order)
    token = session.dig(:guest_order_tokens, order.id.to_s)
    token.present? && ActiveSupport::SecurityUtils.secure_compare(token, order.service_token.to_s)
  end

  def forbidden
    head :forbidden
  end
end
