class CombosController < ApplicationController
  def index
    render json: Combo.where(active: true).order(:name)
  end
end
