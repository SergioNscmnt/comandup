class ComboItem < ApplicationRecord
  belongs_to :combo
  belongs_to :product

  validates :quantity, numericality: { greater_than: 0 }
end
