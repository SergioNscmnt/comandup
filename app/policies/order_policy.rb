class OrderPolicy < ApplicationPolicy
  def show?
    return true if user&.admin?
    return true if user.present? && record.customer_id == user.id

    record.order_type_table? && guest_token?
  end

  def create?
    return true if user&.admin?
    return true if record.order_type_table?

    user.present?
  end

  def cancel?
    return false unless record.can_cancel_by_customer?
    return true if user&.admin?
    return true if user.present? && record.customer_id == user.id

    record.order_type_table? && guest_token?
  end

  def payment?
    return true if user&.admin?
    return true if user.present? && record.customer_id == user.id

    record.order_type_table? && guest_token?
  end

  private

  def guest_token?
    return false unless pundit_user.respond_to?(:[])

    tokens = pundit_user[:guest_order_tokens] || {}
    candidate = tokens[record.id.to_s]
    candidate.present? && ActiveSupport::SecurityUtils.secure_compare(candidate, record.service_token.to_s)
  end
end
