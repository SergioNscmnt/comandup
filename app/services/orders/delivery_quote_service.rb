require "net/http"
require "json"

module Orders
  class DeliveryQuoteService
    RATE_PER_KM_CENTS = 300
    MIN_FEE_CENTS = 1000

    def self.call(cep:)
      new(cep: cep).call
    end

    def initialize(cep:)
      @cep = cep.to_s.gsub(/\D/, "")
    end

    def call
      raise ArgumentError, "CEP inválido para cálculo de entrega." unless @cep.match?(/\A\d{8}\z/)

      origin = store_coordinates
      destination = geocode_cep!(@cep)

      distance_km = haversine_km(origin[:lat], origin[:lng], destination[:lat], destination[:lng]).round(2)
      fee_cents = [(distance_km * fee_per_km_cents).round, minimum_fee_cents].max

      {
        distance_km: distance_km,
        fee_cents: fee_cents
      }
    end

    private

    def settings
      Rails.configuration.x.order_settings
    end

    def fee_per_km_cents
      value = settings.delivery_fee_per_km_cents.to_i
      return RATE_PER_KM_CENTS if value <= 0

      value
    end

    def minimum_fee_cents
      value = settings.delivery_min_fee_cents.to_i
      return MIN_FEE_CENTS if value <= 0

      value
    end

    def store_coordinates
      company = User.company_account
      raise ArgumentError, "Cadastre uma conta de administrador da empresa." unless company

      query = company.company_location_query
      if query.blank?
        raise ArgumentError, "Cadastre o endereço da empresa no painel admin para calcular a entrega."
      end

      geocode_address!(query)
    end

    def geocode_cep!(cep)
      formatted_cep = format_cep(cep)
      via_cep = fetch_via_cep(cep)

      queries = []
      queries << [via_cep["logradouro"], via_cep["bairro"], via_cep["localidade"], via_cep["uf"], formatted_cep, "Brasil"].compact.join(", ")
      queries << [via_cep["bairro"], via_cep["localidade"], via_cep["uf"], formatted_cep, "Brasil"].compact.join(", ")
      queries << [via_cep["localidade"], via_cep["uf"], formatted_cep, "Brasil"].compact.join(", ")
      queries << [formatted_cep, via_cep["localidade"], via_cep["uf"], "Brasil"].compact.join(", ")
      queries << [formatted_cep, "Brasil"].join(", ")

      # 1) Busca estruturada por CEP no Brasil
      structured_uri = URI("https://nominatim.openstreetmap.org/search?#{URI.encode_www_form(postalcode: formatted_cep, countrycodes: "br", format: "jsonv2", limit: 1)}")
      result = parse_coordinates(structured_uri)
      return result if result

      # 2) Fallback em diferentes consultas textuais
      queries.each do |query|
        next if query.blank?

        uri = URI("https://nominatim.openstreetmap.org/search?#{URI.encode_www_form(q: query, countrycodes: "br", format: "jsonv2", limit: 1)}")
        result = parse_coordinates(uri)
        return result if result
      end

      raise ArgumentError, "Não foi possível localizar este CEP para calcular a entrega."
    end

    def geocode_address!(query)
      uri = URI("https://nominatim.openstreetmap.org/search?#{URI.encode_www_form(q: query, format: "jsonv2", limit: 1)}")
      parse_coordinates!(uri, "Não foi possível localizar o endereço da empresa para calcular a entrega.")
    end

    def parse_coordinates(uri)
      body = http_get(uri)
      data = JSON.parse(body)
      first = data.first
      return nil unless first

      { lat: first.fetch("lat").to_f, lng: first.fetch("lon").to_f }
    end

    def parse_coordinates!(uri, error_message)
      result = parse_coordinates(uri)
      raise ArgumentError, error_message unless result

      result
    end

    def fetch_via_cep(cep)
      uri = URI("https://viacep.com.br/ws/#{cep}/json/")
      body = http_get(uri)
      data = JSON.parse(body)
      raise ArgumentError, "CEP inválido para cálculo de entrega." if data["erro"]

      data
    end

    def format_cep(cep)
      "#{cep[0, 5]}-#{cep[5, 3]}"
    end

    def http_get(uri)
      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = "ComandUp/1.0 (delivery-quote)"

      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", read_timeout: 5, open_timeout: 5) do |http|
        response = http.request(request)
        raise ArgumentError, "Não foi possível consultar o serviço de distância no momento." unless response.is_a?(Net::HTTPSuccess)

        response.body
      end
    end

    def haversine_km(lat1, lng1, lat2, lng2)
      rad_per_deg = Math::PI / 180
      r_km = 6371

      dlat = (lat2 - lat1) * rad_per_deg
      dlng = (lng2 - lng1) * rad_per_deg

      lat1_rad = lat1 * rad_per_deg
      lat2_rad = lat2 * rad_per_deg

      a = Math.sin(dlat / 2)**2 + Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(dlng / 2)**2
      c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))

      r_km * c
    end
  end
end
