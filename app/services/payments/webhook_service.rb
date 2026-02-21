module Payments
  class WebhookService
    def initialize(payload:)
      @payload = payload
    end

    def call
      event_id = @payload.fetch("event_id")
      payment = Payment.find_or_initialize_by(provider_event_id: event_id)
      order = Order.find(@payload.fetch("order_id"))

      payment.assign_attributes(
        order: order,
        provider: @payload.fetch("provider", "mock_gateway"),
        provider_reference: @payload["provider_reference"],
        amount_cents: @payload.fetch("amount_cents", order.total_cents),
        status: @payload.fetch("status", "pending"),
        raw_payload: @payload
      )
      payment.approved_at = Time.current if payment.approved?
      payment.save!

      if payment.approved? && order.draft?
        Orders::TransitionService.new(order: order, actor: nil, reason: "webhook_approved").confirm_received
      elsif payment.refused? && !order.canceled?
        order.update!(status: :payment_failed)
      end
    end
  end
end
