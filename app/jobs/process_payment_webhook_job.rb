class ProcessPaymentWebhookJob < ApplicationJob
  queue_as :default

  def perform(payload)
    Payments::WebhookService.new(payload: payload).call
  end
end
