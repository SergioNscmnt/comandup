class Payment < ApplicationRecord
  belongs_to :order

  enum status: {
    pending: 0,
    approved: 1,
    refused: 2,
    refunded: 3
  }

  validates :amount_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :provider, presence: true
end
