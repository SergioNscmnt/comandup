module Admin
  class CompanyProfilesController < BaseController
    require "bigdecimal"

    def edit
      @company_account = company_account
      @address_parts = parse_company_address(@company_account.company_address)
      @operational_fields = {
        delivery_fee_per_km_reais: cents_to_reais(@company_account.company_delivery_fee_per_km_cents),
        delivery_min_fee_reais: cents_to_reais(@company_account.company_delivery_min_fee_cents),
        delivery_min_order_reais: cents_to_reais(@company_account.company_delivery_min_order_cents)
      }
    end

    def update
      @company_account = company_account
      @address_parts = parse_company_address(company_profile_params[:company_address])
      @operational_fields = {
        delivery_fee_per_km_reais: company_profile_params[:company_delivery_fee_per_km_reais],
        delivery_min_fee_reais: company_profile_params[:company_delivery_min_fee_reais],
        delivery_min_order_reais: company_profile_params[:company_delivery_min_order_reais]
      }

      if @company_account.update(company_profile_update_attrs)
        redirect_to edit_admin_company_profile_path, notice: "Endereço da empresa atualizado."
      else
        flash.now[:alert] = @company_account.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def company_account
      User.company_account || current_admin
    end

    def company_profile_params
      params.require(:user).permit(
        :company_address,
        :company_cep,
        :company_street,
        :company_number,
        :company_neighborhood,
        :company_complement,
        :company_delivery_radius_km,
        :company_prep_minutes_base,
        :company_delivery_fee_per_km_reais,
        :company_delivery_min_fee_reais,
        :company_delivery_min_order_reais
      )
    end

    def company_profile_update_attrs
      {
        company_cep: company_profile_params[:company_cep],
        company_address: compose_company_address,
        company_delivery_radius_km: decimal_or_nil(company_profile_params[:company_delivery_radius_km]),
        company_prep_minutes_base: integer_or_nil(company_profile_params[:company_prep_minutes_base]),
        company_delivery_fee_per_km_cents: reais_to_cents(company_profile_params[:company_delivery_fee_per_km_reais]),
        company_delivery_min_fee_cents: reais_to_cents(company_profile_params[:company_delivery_min_fee_reais]),
        company_delivery_min_order_cents: reais_to_cents(company_profile_params[:company_delivery_min_order_reais])
      }
    end

    def reais_to_cents(raw)
      value = raw.to_s.strip
      return nil if value.blank?

      normalized = value.tr(",", ".")
      (BigDecimal(normalized) * 100).round(0).to_i
    rescue ArgumentError
      nil
    end

    def cents_to_reais(cents)
      return nil if cents.nil?

      format("%.2f", cents.to_i / 100.0)
    end

    def presence_or_nil(value)
      value.to_s.strip.presence
    end

    def decimal_or_nil(raw)
      value = raw.to_s.strip
      return nil if value.blank?

      BigDecimal(value.tr(",", ".")).to_s("F")
    rescue ArgumentError
      nil
    end

    def integer_or_nil(raw)
      value = raw.to_s.gsub(/\D/, "")
      return nil if value.blank?

      value.to_i
    end

    def compose_company_address
      parts = [
        company_profile_params[:company_street].to_s.strip.presence,
        normalized_number,
        company_profile_params[:company_neighborhood].to_s.strip.presence,
        company_profile_params[:company_complement].to_s.strip.presence
      ].compact

      composed = parts.join(", ")
      composed.presence || company_profile_params[:company_address]
    end

    def normalized_number
      number = company_profile_params[:company_number].to_s.strip
      return nil if number.blank?

      "Nº #{number}"
    end

    def parse_company_address(raw)
      value = raw.to_s
      parts = value.split(",").map(&:strip)

      street = parts.shift.to_s
      number_part = parts.first.to_s
      number = number_part.sub(/\A[Nn][ºo]\s*/, "")
      if number_part.match?(/\A[Nn][ºo]\s*/)
        parts.shift
      else
        number = ""
      end

      neighborhood = parts.shift.to_s
      complement = parts.join(", ")

      {
        street: street,
        number: number,
        neighborhood: neighborhood,
        complement: complement
      }
    end
  end
end
