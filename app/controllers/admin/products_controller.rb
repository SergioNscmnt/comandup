module Admin
  class ProductsController < BaseController
    require "bigdecimal"
    before_action :set_product, only: [:edit, :update, :destroy]
    before_action :load_categories, only: [:new, :create, :edit, :update]
    before_action :set_price_reais, only: [:new, :edit]
    before_action :set_cost_fields, only: [:new, :edit]

    def new
      @product = Product.new(active: true)
      render layout: false
    end

    def create
      @product = Product.new(product_params.merge(price_cents: money_to_cents(product_params[:price_reais])))

      ActiveRecord::Base.transaction do
        @product.save!
        upsert_product_cost!(@product)
      end

      redirect_to products_path, notice: "Produto criado com sucesso."
    rescue ActiveRecord::RecordInvalid
      @cost_fields = cost_fields_from_params
      flash.now[:alert] = @product.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity, layout: false
    rescue StandardError => e
      @cost_fields = cost_fields_from_params
      flash.now[:alert] = e.message
      render :new, status: :unprocessable_entity, layout: false
    end

    def edit
      render layout: false
    end

    def update
      updates = product_params.except(:price_reais).merge(price_cents: money_to_cents(product_params[:price_reais]))

      ActiveRecord::Base.transaction do
        @product.update!(updates)
        upsert_product_cost!(@product)
      end

      redirect_to products_path, notice: "Produto atualizado com sucesso."
    rescue ActiveRecord::RecordInvalid
      @cost_fields = cost_fields_from_params
      flash.now[:alert] = @product.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity, layout: false
    rescue StandardError => e
      @cost_fields = cost_fields_from_params
      flash.now[:alert] = e.message
      render :edit, status: :unprocessable_entity, layout: false
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

    def product_cost_params
      params.fetch(:product_cost, {}).permit(
        :ingredients_reais,
        :packaging_reais,
        :losses_percent,
        :labor_reais,
        :fixed_allocation_reais,
        :channel_fee_percent
      )
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

    def set_cost_fields
      if @product&.product_cost
        cost = @product.product_cost
        @cost_fields = {
          ingredients_reais: cents_to_money_text(cost.ingredients_cents),
          packaging_reais: cents_to_money_text(cost.packaging_cents),
          losses_percent: decimal_to_percent_text(cost.losses_percent),
          labor_reais: cents_to_money_text(cost.labor_cents),
          fixed_allocation_reais: cents_to_money_text(cost.fixed_allocation_cents),
          channel_fee_percent: decimal_to_percent_text(cost.channel_fee_percent)
        }
      else
        @cost_fields = default_cost_fields
      end
    end

    def default_cost_fields
      {
        ingredients_reais: "0,00",
        packaging_reais: "0,00",
        losses_percent: "0,00",
        labor_reais: "0,00",
        fixed_allocation_reais: "0,00",
        channel_fee_percent: "0,00"
      }
    end

    def cost_fields_from_params
      default_cost_fields.merge(product_cost_params.to_h.symbolize_keys)
    end

    def upsert_product_cost!(product)
      attrs = product_cost_params
      record = product.product_cost || product.build_product_cost
      record.assign_attributes(
        ingredients_cents: money_to_cents(attrs[:ingredients_reais]),
        packaging_cents: money_to_cents(attrs[:packaging_reais]),
        losses_percent: percent_to_decimal(attrs[:losses_percent]),
        labor_cents: money_to_cents(attrs[:labor_reais]),
        fixed_allocation_cents: money_to_cents(attrs[:fixed_allocation_reais]),
        channel_fee_percent: percent_to_decimal(attrs[:channel_fee_percent])
      )
      record.save!
    end

    def money_to_cents(raw)
      value = raw.to_s.strip
      return 0 if value.blank?

      normalized = value.tr(".", "").tr(",", ".")
      (BigDecimal(normalized) * 100).round(0).to_i
    rescue ArgumentError
      0
    end

    def percent_to_decimal(raw)
      value = raw.to_s.strip
      return 0 if value.blank?

      normalized = value.tr(",", ".")
      BigDecimal(normalized).round(2).to_f
    rescue ArgumentError
      0
    end

    def cents_to_money_text(cents)
      format("%.2f", cents.to_i / 100.0).tr(".", ",")
    end

    def decimal_to_percent_text(number)
      format("%.2f", number.to_f).tr(".", ",")
    end
  end
end
