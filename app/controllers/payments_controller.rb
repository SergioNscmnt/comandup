class PaymentsController < ApplicationController
  skip_forgery_protection

  def create
    order = Order.find(params[:order_id])
    authorize order, :payment?

    gateway_result = Payments::GatewayAdapter.charge(order: order, _token: params[:token])

    payment = order.payments.create!(
      status: gateway_result[:status],
      amount_cents: gateway_result[:amount_cents],
      provider: gateway_result[:provider],
      provider_reference: gateway_result[:provider_reference]
    )

    if payment.approved? && order.draft?
      Orders::TransitionService.new(order: order, actor: current_customer, reason: "payment_approved").confirm_received
    elsif payment.refused?
      order.update!(status: :payment_failed)
    end

    render json: payment, status: :created
  end

  def show
    order = Order.find(params[:order_id])
    authorize order, :payment?

    render json: order.payments.order(created_at: :desc).first
  end
end
