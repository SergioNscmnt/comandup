class PaymentReconcileJob < ApplicationJob
  queue_as :default

  def perform
    Payment.pending.where("created_at < ?", 15.minutes.ago).find_each do |payment|
      payment.update!(status: :refused, refused_reason: "timeout")
      next if payment.order.canceled?

      payment.order.update!(status: :payment_failed)
      BroadcastOrderUpdateJob.perform_later(payment.order_id)
    end
  end
end
