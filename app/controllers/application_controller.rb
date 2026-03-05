class ApplicationController < ActionController::Base
  include Pundit::Authorization

  rescue_from Pundit::NotAuthorizedError, with: :forbidden
  helper_method :current_admin, :current_customer, :cart_count, :cart_total_cents, :cart_quantity_for, :cart_note_for, :current_table_number, :table_session_active?

  private

  def current_admin
    @current_admin ||= current_user if current_user&.admin?
  end

  def current_customer
    @current_customer ||= begin
      by_session = current_user if current_user&.customer?
      requested_id = request.headers["X-Customer-Id"]
      by_header = User.customer.find_by(id: requested_id) if requested_id.present?
      by_session || by_header
    end
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
    redirect_to customer_login_path, alert: "Entre com sua conta para continuar."
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

  def cart_quantity_for(product_id)
    cart_entry(product_id)["quantity"].to_i
  end

  def cart_note_for(product_id)
    cart_entry(product_id)["note"].to_s
  end

  def clear_cart!
    session[:cart] = {}
  end

  def current_table_number
    session[:table_number].to_s.strip.presence
  end

  def table_session_active?
    current_table_number.present?
  end

  def load_catalog_mental_triggers(products_scope:)
    @delivery_goal_cents = User.company_account&.company_delivery_min_order_cents.to_i
    @delivery_goal_cents = 4000 if @delivery_goal_cents <= 0

    @catalog_cart_total_cents = cart_total_cents
    @delivery_remaining_cents = [@delivery_goal_cents - @catalog_cart_total_cents, 0].max
    @delivery_progress_percent = ((@catalog_cart_total_cents.to_f / @delivery_goal_cents) * 100).round.clamp(0, 100)

    @delivered_today_count = Order.where(status: :delivered).where(delivered_at: Time.zone.now.all_day).count
    @open_queue_count = Order.open_queue.count
    @avg_prep_minutes = products_scope.average(:prep_minutes).to_f.round
    @avg_prep_minutes = 10 if @avg_prep_minutes <= 0
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
