class AccountsController < ApplicationController
  before_action :authenticate_customer!

  def show
    @customer = current_customer
    @orders_count = @customer.orders.for_customer_channel.count
    @active_orders_count = @customer.orders.for_customer_channel.where(status: [:received, :in_production, :ready]).count
    @last_order = @customer.orders.for_customer_channel.order(created_at: :desc).first
  end

  def update
    @customer = current_customer

    if @customer.update(account_params)
      redirect_to account_path, notice: "Dados da conta atualizados com sucesso."
      return
    end

    @orders_count = @customer.orders.for_customer_channel.count
    @active_orders_count = @customer.orders.for_customer_channel.where(status: [:received, :in_production, :ready]).count
    @last_order = @customer.orders.for_customer_channel.order(created_at: :desc).first
    render :show, status: :unprocessable_entity
  end

  private

  def account_params
    params.require(:user).permit(:name, :email)
  end
end
