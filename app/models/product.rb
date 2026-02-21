class Product < ApplicationRecord
  has_many :combo_items, dependent: :restrict_with_exception
  has_many :order_items, dependent: :restrict_with_exception

  validates :name, presence: true
  validates :price_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :prep_minutes, numericality: { greater_than: 0 }
end
