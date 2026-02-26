module Admin
  class ProductsController < BaseController
    require "bigdecimal"
    before_action :set_product, only: [:edit, :update, :destroy]
    before_action :load_categories, only: [:new, :create, :edit, :update]
    before_action :set_price_reais, only: [:new, :edit]

    def new
      @product = Product.new(active: true)
      render layout: false
    end

    def create
      @product = Product.new(product_params.merge(price_cents: money_to_cents(product_params[:price_reais])))

      if @product.save
        redirect_to products_path, notice: "Produto criado com sucesso."
      else
        flash.now[:alert] = @product.errors.full_messages.to_sentence
        render :new, status: :unprocessable_entity, layout: false
      end
    end

    def edit
      render layout: false
    end

    def update
      updates = product_params.except(:price_reais).merge(price_cents: money_to_cents(product_params[:price_reais]))

      if @product.update(updates)
        redirect_to products_path, notice: "Produto atualizado com sucesso."
      else
        flash.now[:alert] = @product.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_entity, layout: false
      end
    end

    def destroy
      @product.destroy!
      redirect_to products_path, notice: "Produto excluído com sucesso."
    rescue ActiveRecord::DeleteRestrictionError, ActiveRecord::InvalidForeignKey
      redirect_to products_path, alert: "Produto não pode ser excluído porque já está vinculado a pedidos ou combos."
    end

    private

    def product_params
      params.require(:product).permit(:name, :description, :active, :category_id, :price_reais, :image_url)
    end

    def set_product
      @product = Product.find(params[:id])
    end

    def load_categories
      @categories = Category.ordered
    end

    def set_price_reais
      return if @product.blank?
      return if @product.price_cents.blank?

      @product.price_reais = format("%.2f", @product.price_cents / 100.0).tr(".", ",")
    end

    def money_to_cents(raw)
      value = raw.to_s.strip
      return 0 if value.blank?

      normalized = value.tr(".", "").tr(",", ".")
      (BigDecimal(normalized) * 100).round(0).to_i
    rescue ArgumentError
      0
    end
  end
end
