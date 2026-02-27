class Product < ApplicationRecord
  attr_accessor :price_reais

  belongs_to :category

  has_one :product_cost, dependent: :destroy
  has_many :combo_items, dependent: :restrict_with_exception
  has_many :order_items, dependent: :restrict_with_exception

  validates :category, presence: true
  validates :name, presence: true
  validates :price_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :prep_minutes, numericality: { greater_than: 0 }
  validates :image_url,
            format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: "deve ser uma URL válida (http/https)" },
            allow_blank: true
end
