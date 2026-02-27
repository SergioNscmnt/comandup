require "rails_helper"

RSpec.describe Admin::DashboardMetricsService, type: :service do
  before do
    AuditLog.delete_all
    OrderItem.delete_all
    Payment.delete_all
    Order.delete_all
    ProductCost.delete_all
    Product.delete_all
    Category.delete_all
    User.customer.delete_all
  end

  let!(:category) { Category.create!(name: "Lanches #{SecureRandom.hex(4)}") }
  let!(:product) { Product.create!(name: "Burger", category: category, price_cents: 3000, prep_minutes: 12, active: true) }
  let!(:customer) do
    User.customer.create!(
      name: "Cliente BI",
      email: "cliente.bi.#{SecureRandom.hex(4)}@example.com",
      password: "segredo123",
      password_confirmation: "segredo123"
    )
  end

  def create_completed_order!(total_cents:, discount_cents:)
    order = Order.create!(
      customer: customer,
      status: :ready,
      order_type: :delivery,
      subtotal_cents: total_cents,
      discount_cents: discount_cents,
      delivery_fee_cents: 0,
      total_cents: total_cents - discount_cents,
      service_token: SecureRandom.hex(12),
      delivery_address: "Rua Teste, 1"
    )

    OrderItem.create!(
      order: order,
      product: product,
      quantity: 1,
      unit_price_cents: total_cents,
      total_cents: total_cents - discount_cents
    )
    order
  end

  it "returns finance metrics and warning alert when margin is below target" do
    ProductCost.create!(
      product: product,
      ingredients_cents: 1200,
      packaging_cents: 200,
      losses_percent: 10,
      labor_cents: 500,
      fixed_allocation_cents: 200,
      channel_fee_percent: 10
    )
    create_completed_order!(total_cents: 3000, discount_cents: 0)

    metrics = described_class.new(period: "month", order_type: "delivery").call

    expect(metrics.dig(:financials, :net_revenue_cents)).to eq(3000)
    expect(metrics.dig(:financials, :cpv_cents)).to eq(1320)
    expect(metrics[:alerts].map { |a| a[:title] }).to include("Margem operacional abaixo da meta")
  end

  it "returns critical alert when operating margin is negative" do
    ProductCost.create!(
      product: product,
      ingredients_cents: 2500,
      packaging_cents: 600,
      losses_percent: 20,
      labor_cents: 400,
      fixed_allocation_cents: 300,
      channel_fee_percent: 20
    )
    create_completed_order!(total_cents: 3000, discount_cents: 0)

    metrics = described_class.new(period: "month", order_type: "delivery").call

    expect(metrics.dig(:financials, :operating_profit_cents)).to be < 0
    expect(metrics[:alerts].map { |a| a[:title] }).to include("Margem operacional negativa")
  end

  it "builds scenario simulation with recommendation and hero/problem outputs" do
    ProductCost.create!(
      product: product,
      ingredients_cents: 900,
      packaging_cents: 120,
      losses_percent: 5,
      labor_cents: 200,
      fixed_allocation_cents: 100,
      channel_fee_percent: 8
    )
    create_completed_order!(total_cents: 3000, discount_cents: 0)

    metrics = described_class.new(
      period: "month",
      order_type: "delivery",
      scenario: {
        discount_percent: 5,
        combo_factor: 0.9,
        price_increase_percent: 2,
        free_shipping_absorbed: "1",
        elasticity: -1.2,
        margin_min_percent: 25
      }
    ).call

    expect(metrics[:simulation]).to be_present
    expect(metrics.dig(:simulation, :products).size).to be >= 1
    expect(metrics.dig(:simulation, :hero_product, :product_name)).to eq(product.name)
    expect(metrics.dig(:simulation, :recommendation, :candidates)).to be_present
  end
end
