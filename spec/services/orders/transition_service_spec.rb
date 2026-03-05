require "rails_helper"

RSpec.describe Orders::TransitionService do
  before do
    Order.open_queue.update_all(status: Order.statuses[:delivered], started_at: Time.current, ready_at: Time.current, delivered_at: Time.current)
  end

  describe "#start_production" do
    let(:admin) do
      User.create!(
        name: "Admin",
        email: "admin-fifo@example.com",
        role: :admin,
        password: "password123"
      )
    end

    it "starts production for the first order in FIFO queue" do
      first_order = create_received_order(created_at: 2.minutes.ago)
      second_order = create_received_order(created_at: 1.minute.ago)

      described_class.new(order: first_order, actor: admin).start_production

      expect(first_order.reload.status).to eq("in_production")
      expect(first_order.started_at).to be_present
      expect(second_order.reload.status).to eq("received")
    end

    it "rejects starting production for an order that is not first in FIFO queue" do
      first_order = create_received_order(created_at: 2.minutes.ago)
      second_order = create_received_order(created_at: 1.minute.ago)

      expect do
        described_class.new(order: second_order, actor: admin).start_production
      end.to raise_error(
        Orders::TransitionService::InvalidTransition,
        "Respeite a fila FIFO: inicie primeiro o pedido ##{first_order.id}."
      )

      expect(first_order.reload.status).to eq("received")
      expect(second_order.reload.status).to eq("received")
    end
  end

  describe "full lifecycle" do
    let(:admin) do
      User.create!(
        name: "Admin Lifecycle",
        email: "admin-lifecycle@example.com",
        role: :admin,
        password: "password123"
      )
    end

    it "transitions from received to delivered with timestamps and audit trail" do
      order = create_received_order(created_at: 1.minute.ago)
      service = described_class.new(order: order, actor: admin, reason: "spec_flow")

      service.start_production
      service.finish
      service.mark_delivered

      order.reload

      expect(order.status).to eq("delivered")
      expect(order.started_at).to be_present
      expect(order.ready_at).to be_present
      expect(order.delivered_at).to be_present

      events = AuditLog.where(order_id: order.id).order(:created_at).pluck(:event)
      expect(events).to include("start_production", "finish", "mark_delivered")
    end
  end

  def create_received_order(created_at:)
    Order.create!(
      status: :received,
      order_type: :table,
      table_number: "Mesa 7",
      subtotal_cents: 2500,
      discount_cents: 0,
      total_cents: 2500,
      delivery_fee_cents: 0,
      service_token: SecureRandom.hex(16),
      created_at: created_at,
      updated_at: created_at
    )
  end
end
