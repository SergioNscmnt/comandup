class ProductsController < ApplicationController
  def index
    @products = Product.where(active: true).order(:name)

    respond_to do |format|
      format.html
      format.json { render json: @products }
    end
  end
end
