require "rails_helper"

RSpec.describe "Orders index", type: :request do
  before { host! "localhost" }

  def create_order!(customer:, order_type:)
    attrs = {}
    attrs[:delivery_address] = "Rua Teste, 123" if order_type.to_sym == :delivery
    attrs[:table_number] = "A1" if order_type.to_sym == :table

    Order.create!(
      customer: customer,
      order_type: order_type,
      status: :received,
      subtotal_cents: 1500,
      discount_cents: 0,
      delivery_fee_cents: 0,
      total_cents: 1500,
      service_token: SecureRandom.hex(16),
      **attrs
    )
  end

  it "shows pickup and delivery orders for the customer panel" do
    customer = User.customer.create!(
      name: "Cliente Teste",
      email: "cliente.orders@example.com",
      password: "segredo123",
      password_confirmation: "segredo123"
    )

    pickup_order = create_order!(customer: customer, order_type: :pickup)
    delivery_order = create_order!(customer: customer, order_type: :delivery)
    table_order = create_order!(customer: customer, order_type: :table)
    other_customer = User.customer.create!(
      name: "Outro Cliente",
      email: "outro.orders@example.com",
      password: "segredo123",
      password_confirmation: "segredo123"
    )
    other_pickup_order = create_order!(customer: other_customer, order_type: :pickup)

    get orders_path, headers: { "HTTP_X_CUSTOMER_ID" => customer.id.to_s }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("##{pickup_order.id}")
    expect(response.body).to include("##{delivery_order.id}")
    expect(response.body).not_to include("##{table_order.id}")
    expect(response.body).not_to include("##{other_pickup_order.id}")
  end
end
