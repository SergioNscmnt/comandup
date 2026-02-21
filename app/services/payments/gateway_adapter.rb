module Payments
  class GatewayAdapter
    def self.charge(order:, _token: nil)
      {
        provider: "mock_gateway",
        provider_reference: "pay_#{SecureRandom.hex(8)}",
        status: :approved,
        amount_cents: order.total_cents
      }
    end
  end
end
