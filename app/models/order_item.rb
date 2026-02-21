class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :product, optional: true
  belongs_to :combo, optional: true

  validates :quantity, numericality: { greater_than: 0 }
  validates :unit_price_cents, :total_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :notes, length: { maximum: 255 }, allow_blank: true
  validate :product_or_combo_present

  private

  def product_or_combo_present
    return if product_id.present? || combo_id.present?

    errors.add(:base, "order item must reference product or combo")
  end
end
