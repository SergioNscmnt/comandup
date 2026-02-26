require "net/http"
require "json"

module Geo
  class OsmSuggestionService
    LIMIT = 7

    def self.call(field:, query:, region: nil)
      new(field: field, query: query, region: region).call
    end

    def initialize(field:, query:, region: nil)
      @field = field.to_s
      @query = query.to_s.strip
      @city = region.is_a?(Hash) ? region[:city].to_s.strip : ""
      @uf = region.is_a?(Hash) ? region[:uf].to_s.strip.upcase : ""
    end

    def call
      raise ArgumentError, "Consulta inválida para sugestão." if @query.length < 3

      suggestions = []
      seen = {}

      search_queries.each do |text_query|
        uri = URI("https://nominatim.openstreetmap.org/search?#{URI.encode_www_form(params_for_search(text_query))}")
        body = http_get(uri)
        data = JSON.parse(body)

        build_suggestions(data).each do |suggestion|
          key = suggestion[:value].downcase
          next if seen[key]

          seen[key] = true
          suggestions << suggestion
          return suggestions.first(LIMIT) if suggestions.size >= LIMIT
        end
      end

      suggestions
    end

    private

    def params_for_search(text_query)
      {
        q: text_query,
        countrycodes: "br",
        format: "jsonv2",
        addressdetails: 1,
        limit: LIMIT
      }
    end

    def search_queries
      main = if @field == "street"
               @query
             elsif @field == "neighborhood"
               "bairro #{@query}"
             else
               raise ArgumentError, "Campo inválido para sugestão."
             end

      queries = []
      if @city.present? && @uf.present?
        queries << "#{main}, #{@city}, #{@uf}, Brasil"
      elsif @uf.present?
        queries << "#{main}, #{@uf}, Brasil"
      end
      queries << "#{main}, Brasil"
      queries.uniq
    end

    def build_suggestions(data)
      seen = {}

      data.filter_map do |item|
        next unless matches_region?(item)

        value = extract_value(item)
        next if value.blank?

        normalized = value.downcase
        next if seen[normalized]

        seen[normalized] = true
        { value: value, label: build_label(item, value) }
      end
    end

    def matches_region?(item)
      return true if @uf.blank? && @city.blank?

      address = item["address"] || {}
      state_code = address["ISO3166-2-lvl4"].to_s.split("-").last.to_s.upcase
      state = address["state"].to_s.upcase
      city = first_present(address["city"], address["town"], address["village"], address["municipality"]).to_s

      uf_match = @uf.blank? || state_code == @uf || state.include?(@uf)
      city_match = @city.blank? || city.casecmp(@city).zero?
      uf_match && city_match
    end

    def extract_value(item)
      address = item["address"] || {}

      if @field == "street"
        return first_present(address["road"], address["pedestrian"], address["residential"], address["footway"], address["path"])
      end

      if @field == "neighborhood"
        return first_present(address["suburb"], address["neighbourhood"], address["quarter"], address["city_district"])
      end

      nil
    end

    def build_label(item, value)
      address = item["address"] || {}
      city = first_present(address["city"], address["town"], address["village"], address["municipality"])
      state = address["state"]

      suffix = [city, state].compact.join(" - ")
      suffix.present? ? "#{value} (#{suffix})" : value
    end

    def first_present(*values)
      values.find { |value| value.to_s.strip.present? }&.to_s&.strip
    end

    def http_get(uri)
      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = "ComandUp/1.0 (osm-autocomplete)"

      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", read_timeout: 5, open_timeout: 5) do |http|
        response = http.request(request)
        raise ArgumentError, "Não foi possível consultar o OpenStreetMap no momento." unless response.is_a?(Net::HTTPSuccess)

        response.body
      end
    end
  end
end
