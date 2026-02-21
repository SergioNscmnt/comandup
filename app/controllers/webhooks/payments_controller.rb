module Webhooks
  class PaymentsController < ApplicationController
    skip_forgery_protection

    def create
      ProcessPaymentWebhookJob.perform_later(params.to_unsafe_h)
      head :accepted
    end
  end
end
