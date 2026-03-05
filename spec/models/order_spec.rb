require "rails_helper"

RSpec.describe Order, type: :model do
  def create_customer!(suffix: SecureRandom.hex(4))
    User.customer.create!(
      name: "Cliente #{suffix}",
      email: "cliente.order.#{suffix}@example.com",
      password: "segredo123",
      password_confirmation: "segredo123"
    )
  end

  def build_order(order_type:, suffix: SecureRandom.hex(4), **attrs)
    defaults = {
      customer: create_customer!(suffix: suffix),
      status: :received,
      subtotal_cents: 1500,
      discount_cents: 0,
      total_cents: 1500,
      delivery_fee_cents: 0,
      service_token: "order-#{suffix}-#{SecureRandom.hex(8)}"
    }

    Order.new(defaults.merge(attrs).merge(order_type: order_type))
  end

  it "requires table_number for table orders" do
    order = build_order(order_type: :table, table_number: nil, customer: nil)

    expect(order).not_to be_valid
    expect(order.errors[:table_number]).to be_present
  end

  it "requires customer for pickup orders" do
    order = build_order(order_type: :pickup, customer: nil)

    expect(order).not_to be_valid
    expect(order.errors[:customer_id]).to be_present
  end

  it "requires delivery_address for delivery orders" do
    order = build_order(order_type: :delivery, delivery_address: nil)

    expect(order).not_to be_valid
    expect(order.errors[:delivery_address]).to be_present
  end

  it "returns received and in_production in open_queue ordered by created_at" do
    old_received = Order.create!(
      status: :received,
      order_type: :table,
      table_number: "Mesa 1",
      subtotal_cents: 1000,
      discount_cents: 0,
      total_cents: 1000,
      delivery_fee_cents: 0,
      service_token: SecureRandom.hex(16),
      created_at: 2.minutes.ago,
      updated_at: 2.minutes.ago
    )
    newer_in_production = Order.create!(
      status: :in_production,
      order_type: :table,
      table_number: "Mesa 2",
      subtotal_cents: 1000,
      discount_cents: 0,
      total_cents: 1000,
      delivery_fee_cents: 0,
      service_token: SecureRandom.hex(16),
      created_at: 1.minute.ago,
      updated_at: 1.minute.ago
    )
    Order.create!(
      status: :delivered,
      order_type: :table,
      table_number: "Mesa 3",
      subtotal_cents: 1000,
      discount_cents: 0,
      total_cents: 1000,
      delivery_fee_cents: 0,
      service_token: SecureRandom.hex(16)
    )

    expect(Order.open_queue).to eq([old_received, newer_in_production])
  end
end
