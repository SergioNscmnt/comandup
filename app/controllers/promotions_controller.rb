class PromotionsController < ApplicationController
  def index
    render json: Promotion.active_now.order(:name)
  end
end
