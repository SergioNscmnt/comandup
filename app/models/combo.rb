class Combo < ApplicationRecord
  has_many :combo_items, dependent: :destroy
  has_many :products, through: :combo_items
  has_many :order_items, dependent: :restrict_with_exception

  validates :name, presence: true
  validates :description, length: { maximum: 800 }, allow_blank: true
  validates :price_cents, numericality: { greater_than_or_equal_to: 0 }
end
