class GeoController < ApplicationController
  require "net/http"
  require "json"

  def suggestions
    field = params[:field].to_s
    query = params[:q].to_s.strip
    region = region_context

    if query.length < 3
      render json: { suggestions: [] }
      return
    end

    unless %w[street neighborhood].include?(field)
      render json: { error: "Campo inválido para sugestão." }, status: :unprocessable_entity
      return
    end

    suggestions = Geo::OsmSuggestionService.call(field: field, query: query, region: region)
    render json: { suggestions: suggestions }
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue StandardError
    render json: { error: "Não foi possível buscar sugestões agora." }, status: :service_unavailable
  end

  private

  def region_context
    explicit = {
      city: params[:city].to_s.strip.presence,
      uf: params[:uf].to_s.strip.presence&.upcase
    }.compact
    return explicit if explicit.present?

    company = User.company_account
    return {} unless company

    by_cep = city_uf_from_cep(company.company_cep)
    return by_cep if by_cep.present?

    city_uf_from_address(company.company_address)
  end

  def city_uf_from_cep(cep)
    digits = cep.to_s.gsub(/\D/, "")
    return {} unless digits.match?(/\A\d{8}\z/)

    uri = URI("https://viacep.com.br/ws/#{digits}/json/")
    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = "ComandUp/1.0 (geo-suggestions)"

    body = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 4, open_timeout: 4) do |http|
      response = http.request(request)
      return {} unless response.is_a?(Net::HTTPSuccess)

      response.body
    end

    data = JSON.parse(body)
    return {} if data["erro"]

    city = data["localidade"].to_s.strip
    uf = data["uf"].to_s.strip.upcase
    return {} if city.blank? || uf.blank?

    { city: city, uf: uf }
  rescue StandardError
    {}
  end

  def city_uf_from_address(address)
    value = address.to_s
    match = value.match(/,\s*([^,]+?)\s*-\s*([A-Z]{2})\b/)
    return {} unless match

    { city: match[1].to_s.strip, uf: match[2].to_s.strip.upcase }
  end
end
