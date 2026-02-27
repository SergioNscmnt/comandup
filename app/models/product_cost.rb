class ProductCost < ApplicationRecord
  belongs_to :product

  validates :ingredients_cents, :packaging_cents, :labor_cents, :fixed_allocation_cents,
            numericality: { greater_than_or_equal_to: 0 }
  validates :losses_percent, :channel_fee_percent,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
end
