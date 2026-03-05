require "rails_helper"

RSpec.describe Payment, type: :model do
  def create_customer!(suffix: SecureRandom.hex(4))
    User.customer.create!(
      name: "Cliente #{suffix}",
      email: "cliente.payment.#{suffix}@example.com",
      password: "segredo123",
      password_confirmation: "segredo123"
    )
  end

  def create_order!(suffix: SecureRandom.hex(4))
    Order.create!(
      customer: create_customer!(suffix: suffix),
      order_type: :pickup,
      status: :received,
      subtotal_cents: 2000,
      discount_cents: 0,
      total_cents: 2000,
      delivery_fee_cents: 0,
      service_token: "payment-order-#{suffix}-#{SecureRandom.hex(8)}"
    )
  end

  it "is valid with order, provider and non-negative amount" do
    payment = described_class.new(order: create_order!, provider: "mock", amount_cents: 2000)

    expect(payment).to be_valid
  end

  it "requires provider" do
    payment = described_class.new(order: create_order!, provider: nil, amount_cents: 1000)

    expect(payment).not_to be_valid
    expect(payment.errors[:provider]).to be_present
  end

  it "requires non-negative amount_cents" do
    payment = described_class.new(order: create_order!, provider: "mock", amount_cents: -1)

    expect(payment).not_to be_valid
    expect(payment.errors[:amount_cents]).to be_present
  end
end
