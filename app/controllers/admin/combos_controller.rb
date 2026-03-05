module Admin
  class CombosController < BaseController
    require "bigdecimal"

    def new
      @combo = Combo.new(active: true)
      render layout: false
    end

    def create
      @combo = Combo.new(combo_params.merge(price_cents: money_to_cents(combo_params[:price_reais])))

      if @combo.save
        redirect_to products_path, notice: "Combo criado com sucesso."
      else
        flash.now[:alert] = @combo.errors.full_messages.to_sentence
        render :new, status: :unprocessable_entity, layout: false
      end
    end

    private

    def combo_params
      params.require(:combo).permit(:name, :description, :active, :price_reais, :image_url)
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
