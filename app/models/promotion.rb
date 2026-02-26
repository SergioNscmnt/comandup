class Promotion < ApplicationRecord
  COUPON_CATEGORIES = %w[lanches combos primeiro_pedido sucos sobremesas all].freeze

  enum discount_kind: { percentage: 0, fixed_value: 1 }, _prefix: :discount_kind

  scope :active_now, lambda {
    where(active: true)
      .where("starts_at IS NULL OR starts_at <= ?", Time.current)
      .where("ends_at IS NULL OR ends_at >= ?", Time.current)
      .where("quantity IS NULL OR quantity > 0")
  }

  validates :name, presence: true
  validates :discount_percent, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, if: :discount_kind_percentage?
  validates :discount_value_cents, numericality: { greater_than_or_equal_to: 0 }, if: :discount_kind_fixed_value?
  validates :quantity, numericality: { greater_than_or_equal_to: 0, only_integer: true }, allow_nil: true
  validates :coupon_category, inclusion: { in: COUPON_CATEGORIES }
  validate :expiration_after_start

  private

  def expiration_after_start
    return if starts_at.blank? || ends_at.blank?
    return if ends_at >= starts_at

    errors.add(:ends_at, "deve ser maior ou igual à data de criação")
  end
end
