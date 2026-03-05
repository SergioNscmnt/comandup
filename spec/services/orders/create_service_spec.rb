require "rails_helper"

RSpec.describe Orders::CreateService do
  def create_customer!(suffix: SecureRandom.hex(4))
    User.customer.create!(
      name: "Cliente #{suffix}",
      email: "cliente.create-service.#{suffix}@example.com",
      password: "segredo123",
      password_confirmation: "segredo123"
    )
  end

  def create_product!(suffix: SecureRandom.hex(4), price_cents: 1200)
    category = Category.create!(name: "Categoria CreateService #{suffix}")
    Product.create!(
      name: "Produto CreateService #{suffix}",
      category: category,
      price_cents: price_cents,
      prep_minutes: 10
    )
  end

  describe "#call" do
    it "creates only one order when the same idempotency_key is reused" do
      customer = create_customer!
      product = create_product!
      idempotency_key = "idem-#{SecureRandom.hex(8)}"

      first_order = described_class.new(
        customer: customer,
        items: [{ product_id: product.id, quantity: 2 }],
        order_type: :pickup,
        idempotency_key: idempotency_key
      ).call

      second_order = described_class.new(
        customer: customer,
        items: [{ product_id: product.id, quantity: 2 }],
        order_type: :pickup,
        idempotency_key: idempotency_key
      ).call

      expect(second_order.id).to eq(first_order.id)
      expect(Order.where(idempotency_key: idempotency_key).count).to eq(1)
      expect(first_order.order_items.count).to eq(1)
    end

    it "creates distinct orders when idempotency_key is absent" do
      customer = create_customer!
      product = create_product!

      first_order = described_class.new(
        customer: customer,
        items: [{ product_id: product.id, quantity: 1 }],
        order_type: :pickup
      ).call
      second_order = described_class.new(
        customer: customer,
        items: [{ product_id: product.id, quantity: 1 }],
        order_type: :pickup
      ).call

      expect(second_order.id).not_to eq(first_order.id)
    end
  end
end
