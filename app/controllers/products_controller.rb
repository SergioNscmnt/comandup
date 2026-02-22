class ProductsController < ApplicationController
  def index
    @categories = Category.ordered
    @selected_category_id = params[:category_id].presence&.to_i

    @products = Product.where(active: true).includes(:category)
    @products = @products.where(category_id: @selected_category_id) if @selected_category_id.present?
    @products = @products.order(:name)

    respond_to do |format|
      format.html
      format.json { render json: @products }
    end
  end
end
