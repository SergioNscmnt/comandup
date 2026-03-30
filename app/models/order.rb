class Order < ApplicationRecord
  require "securerandom"
  CHECKOUT_SERVICE_RATE = 0.10
  TABLE_CHECKOUT_EXCLUDED_STATUSES = %w[draft delivered canceled payment_failed].freeze
  TABLE_DASHBOARD_ACTIVE_STATUSES = %w[received in_production ready].freeze
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

  scope :open_queue, -> { where(status: [statuses[:received], statuses[:in_production]]).order(created_at: :asc, id: :asc) }
  scope :for_customer_channel, -> { where(order_type: %i[pickup delivery]) }
  scope :table_checkout_open, -> { where(order_type: :table).where.not(status: TABLE_CHECKOUT_EXCLUDED_STATUSES) }

  validates :subtotal_cents, :discount_cents, :total_cents, :delivery_fee_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :delivery_distance_km, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :table_number, presence: true, if: :order_type_table?
  validates :customer_id, presence: true, if: -> { order_type_pickup? || order_type_delivery? }
  validates :delivery_address, presence: true, if: :order_type_delivery?
  validates :service_token, presence: true, uniqueness: true
  validates :idempotency_key, uniqueness: true, allow_nil: true

  def can_cancel_by_customer?
    received?
  end

  def human_status
    I18n.t("activerecord.attributes.order.statuses.#{status}", default: status.humanize)
  end

  def human_order_type
    I18n.t("activerecord.attributes.order.order_types.#{order_type}", default: order_type.humanize)
  end

  def human_table_label
    number = table_number.to_s[/\d+/]
    return "Mesa #{number}" if number.present?

    "Mesa"
  end

  def table_number_value
    table_number.to_s[/\d+/].to_i
  end

  def dashboard_table_key
    value = table_number_value
    return if value.zero?

    value
  end

  def active_for_table_dashboard?
    order_type_table? && TABLE_DASHBOARD_ACTIVE_STATUSES.include?(status)
  end

  def dashboard_elapsed_minutes(reference_time: Time.current)
    started = ready_at || started_at || received_at || created_at
    return 0 unless started

    [((reference_time - started) / 60).floor, 0].max
  end

  def attention_for_table_dashboard?(reference_time: Time.current)
    return false unless active_for_table_dashboard?

    return true if ready? && ready_at.present? && ready_at <= 5.minutes.ago

    eta_minutes.present? && dashboard_elapsed_minutes(reference_time:) > eta_minutes
  end

  def checkout_reference
    "COM-#{id.to_s.rjust(4, '0')}"
  end

  def table_checkout_orders
    return [] unless order_type_table?

    table_key = dashboard_table_key
    return [] if table_key.blank?

    @table_checkout_orders ||= self.class
      .table_checkout_open
      .includes(:customer, order_items: [product: :category, combo: {}])
      .to_a
      .select { |order| order.dashboard_table_key == table_key }
      .sort_by { |order| [order.created_at, order.id] }
  end

  def table_checkout_ready?
    orders = table_checkout_orders
    orders.present? && orders.all?(&:ready?)
  end

  def table_checkout_subtotal_cents
    table_checkout_orders.sum(&:subtotal_cents)
  end

  def table_checkout_discount_cents
    table_checkout_orders.sum(&:discount_cents)
  end

  def table_checkout_service_fee_cents
    (table_checkout_subtotal_cents * CHECKOUT_SERVICE_RATE).round
  end

  def table_checkout_total_cents
    table_checkout_subtotal_cents + table_checkout_service_fee_cents - table_checkout_discount_cents
  end

  def table_checkout_item_count
    table_checkout_orders.sum { |order| order.order_items.sum(&:quantity) }
  end

  def table_checkout_people_count
    [table_checkout_orders.size, 1].max
  end

  def table_checkout_duration_minutes(reference_time: Time.current)
    started = table_checkout_orders.map(&:created_at).compact.min
    return 0 unless started

    [((reference_time - started) / 60).floor, 0].max
  end

  def table_checkout_average_per_person_cents
    return 0 if table_checkout_people_count.zero?

    (table_checkout_total_cents / table_checkout_people_count.to_f).round
  end

  def table_menu_current_total_cents
    table_checkout_subtotal_cents
  end

  def add_product_to_table!(product, quantity: 1, notes: nil)
    raise ActiveRecord::RecordInvalid, self unless order_type_table?

    target_order = table_menu_target_order!

    ActiveRecord::Base.transaction do
      target_order.order_items.create!(
        product: product,
        quantity: quantity,
        unit_price_cents: product.price_cents,
        total_cents: product.price_cents * quantity,
        notes: notes.to_s.strip.presence
      )
      subtotal = target_order.order_items.sum(:total_cents)
      target_order.update!(subtotal_cents: subtotal, total_cents: subtotal + target_order.delivery_fee_cents - target_order.discount_cents)
    end

    RecalculateQueueEtaJob.perform_later
    BroadcastOrderUpdateJob.perform_later(target_order.id)
    BroadcastQueueUpdateJob.perform_later
    target_order
  end

  def table_checkout_status_label
    return "Cozinha Finalizada" if table_checkout_ready?

    in_production_count = table_checkout_orders.count(&:in_production?)
    received_count = table_checkout_orders.count(&:received?)
    return "#{in_production_count} item(ns) em preparo" if in_production_count.positive?
    return "#{received_count} item(ns) aguardando produção" if received_count.positive?

    "Conta em atualização"
  end

  def table_checkout_groups
    grouped_items = table_checkout_orders.flat_map(&:order_items).group_by do |item|
      item.product&.category&.name.presence || item.combo&.name.presence || "Itens"
    end

    grouped_items.map do |group_name, items|
      {
        title: group_name.to_s.upcase,
        items: items.map do |item|
          {
            quantity: item.quantity,
            name: item.product&.name || item.combo&.name || "Item",
            note: item.notes.to_s.strip.presence,
            total_cents: item.total_cents
          }
        end
      }
    end
  end

  def table_command_opened_at_label
    first_order = table_checkout_orders.min_by(&:created_at)
    first_order&.created_at&.strftime("%H:%M") || "--:--"
  end

  def table_command_active_for_label(reference_time: Time.current)
    minutes = table_checkout_duration_minutes(reference_time:)
    return "Ativa agora" if minutes.zero?

    "Ativa há #{ActionController::Base.helpers.distance_of_time_in_words(0, minutes.minutes, include_seconds: false)}"
  end

  def table_command_rows(reference_time: Time.current)
    table_checkout_orders.flat_map do |order|
      order.order_items.map do |item|
        {
          quantity: item.quantity,
          name: item.product&.name || item.combo&.name || "Item",
          note: item.notes.to_s.strip.presence,
          unit_price_cents: item.unit_price_cents,
          total_cents: item.total_cents,
          waiting_label: table_command_waiting_label(order, reference_time:),
          state: table_command_item_state(order)
        }
      end
    end
  end

  def table_command_info
    {
      waiter_name: "Roberto S.",
      opening_label: table_command_opened_at_label,
      occupancy_dots: [table_checkout_people_count, 4].max,
      occupancy_active: table_checkout_people_count
    }
  end

  def table_command_note
    latest_note = table_checkout_orders
      .flat_map(&:order_items)
      .map { |item| item.notes.to_s.strip.presence }
      .compact
      .last

    latest_note.presence || "Cliente solicitou reserva de mesa para aniversário. Aplicar cortesia de sobremesa ao final."
  end

  private

  def table_menu_target_order!
    active_target = table_checkout_orders.reverse.find { |order| order.received? || order.in_production? }
    return active_target if active_target.present?

    self.class.create!(
      customer: customer,
      order_type: :table,
      table_number: table_number,
      status: :received,
      service_token: SecureRandom.hex(16),
      subtotal_cents: 0,
      discount_cents: 0,
      delivery_fee_cents: 0,
      total_cents: 0,
      received_at: Time.current
    )
  end

  def table_command_waiting_label(order, reference_time:)
    return "cozinha finalizada" if order.ready?
    return "aguardando preparo" if order.received?

    elapsed = order.dashboard_elapsed_minutes(reference_time:)
    "aguardando há #{elapsed}min"
  end

  def table_command_item_state(order)
    return :ready if order.ready?
    return :pending if order.in_production?

    :queued
  end
end
