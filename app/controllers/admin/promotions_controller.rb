module Admin
  class PromotionsController < BaseController
    require "bigdecimal"

    def new
      @promotion = Promotion.new(active: true, discount_kind: :percentage, starts_at: Time.current)
      render layout: false
    end

    def create
      @promotion = Promotion.new(base_promotion_params)
      assign_discount_value!

      if @promotion.save
        redirect_to products_path, notice: "Cupom criado com sucesso."
      else
        flash.now[:alert] = @promotion.errors.full_messages.to_sentence
        render :new, status: :unprocessable_entity, layout: false
      end
    end

    private

    def base_promotion_params
      params.require(:promotion).permit(
        :name,
        :discount_kind,
        :discount_percent,
        :quantity,
        :starts_at,
        :ends_at,
        :active,
        :coupon_category
      )
    end

    def assign_discount_value!
      if @promotion.discount_kind_fixed_value?
        @promotion.discount_percent = 0
        @promotion.discount_value_cents = money_to_cents(params.dig(:promotion, :discount_value_reais))
      else
        @promotion.discount_value_cents = 0
      end
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
