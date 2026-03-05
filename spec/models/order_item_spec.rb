require "rails_helper"

RSpec.describe OrderItem, type: :model do
  def create_customer!(suffix: SecureRandom.hex(4))
    User.customer.create!(
      name: "Cliente #{suffix}",
      email: "cliente.order_item.#{suffix}@example.com",
      password: "segredo123",
      password_confirmation: "segredo123"
    )
  end

  def create_order!(suffix: SecureRandom.hex(4))
    Order.create!(
      customer: create_customer!(suffix: suffix),
      order_type: :pickup,
      status: :received,
      subtotal_cents: 1000,
      discount_cents: 0,
      total_cents: 1000,
      delivery_fee_cents: 0,
      service_token: "svc-#{suffix}-#{SecureRandom.hex(8)}"
    )
  end

  def create_product!(suffix: SecureRandom.hex(4))
    category = Category.create!(name: "Categoria Produto #{suffix}")
    Product.create!(name: "Produto #{suffix}", category: category, price_cents: 1000, prep_minutes: 12)
  end

  def create_combo!(suffix: SecureRandom.hex(4))
    Combo.create!(name: "Combo #{suffix}", price_cents: 2200)
  end

  it "is valid when references a product" do
    item = described_class.new(order: create_order!, product: create_product!, quantity: 1, unit_price_cents: 1000, total_cents: 1000)

    expect(item).to be_valid
  end

  it "is valid when references a combo" do
    item = described_class.new(order: create_order!, combo: create_combo!, quantity: 1, unit_price_cents: 2200, total_cents: 2200)

    expect(item).to be_valid
  end

  it "requires product or combo" do
    item = described_class.new(order: create_order!, quantity: 1, unit_price_cents: 1000, total_cents: 1000)

    expect(item).not_to be_valid
    expect(item.errors[:base]).to include("order item must reference product or combo")
  end
end
