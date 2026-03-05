require "rails_helper"

RSpec.describe AuditLog, type: :model do
  def create_customer!(suffix: SecureRandom.hex(4))
    User.customer.create!(
      name: "Cliente #{suffix}",
      email: "cliente.#{suffix}@example.com",
      password: "segredo123",
      password_confirmation: "segredo123"
    )
  end

  def create_order!(customer: create_customer!, service_token: SecureRandom.hex(16))
    Order.create!(
      customer: customer,
      order_type: :pickup,
      status: :received,
      subtotal_cents: 1000,
      discount_cents: 0,
      total_cents: 1000,
      delivery_fee_cents: 0,
      service_token: service_token
    )
  end

  it "is valid with order and event" do
    order = create_order!
    audit_log = described_class.new(order: order, event: "start_production")

    expect(audit_log).to be_valid
  end

  it "requires event" do
    audit_log = described_class.new(order: create_order!, event: nil)

    expect(audit_log).not_to be_valid
    expect(audit_log.errors[:event]).to be_present
  end

  it "allows nil user" do
    audit_log = described_class.new(order: create_order!, event: "finish", user: nil)

    expect(audit_log).to be_valid
  end
end
