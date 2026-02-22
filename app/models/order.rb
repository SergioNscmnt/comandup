class Order < ApplicationRecord
  OPEN_STATUSES = %w[received in_production].freeze

  belongs_to :customer, class_name: "User", inverse_of: :orders, optional: true
  has_many :order_items, dependent: :destroy
  has_many :payments, dependent: :destroy
  has_many :audit_logs, dependent: :destroy

  enum status: {
    draft: 0,
    received: 1,
    in_production: 2,
    ready: 3,
    delivered: 4,
    canceled: 5,
    payment_failed: 6
  }
  enum order_type: { table: 0, pickup: 1, delivery: 2 }, _prefix: :order_type

  scope :open_queue, -> { where(status: [statuses[:received], statuses[:in_production]]).order(created_at: :asc) }
  scope :for_customer_channel, -> { where(order_type: [order_types[:pickup], order_types[:delivery]]) }

  validates :subtotal_cents, :discount_cents, :total_cents, :delivery_fee_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :delivery_distance_km, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :table_number, presence: true, if: :order_type_table?
  validates :customer_id, presence: true, if: -> { order_type_pickup? || order_type_delivery? }
  validates :delivery_address, presence: true, if: :order_type_delivery?
  validates :service_token, presence: true, uniqueness: true

  def can_cancel_by_customer?
    received?
  end

  def human_status
    I18n.t("activerecord.attributes.order.statuses.#{status}", default: status.humanize)
  end

  def human_order_type
    I18n.t("activerecord.attributes.order.order_types.#{order_type}", default: order_type.humanize)
  end
end
