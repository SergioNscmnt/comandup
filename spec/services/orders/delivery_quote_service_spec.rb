require "rails_helper"

RSpec.describe Orders::DeliveryQuoteService do
  describe "#call" do
    it "uses CEP-based fallback when company address cannot be geocoded" do
      admin = User.create!(
        name: "Admin Delivery",
        email: "admin-delivery-#{SecureRandom.hex(4)}@example.com",
        role: :admin,
        password: "password123",
        company_address: "Endereco sem geocoding",
        company_cep: "76804-320"
      )

      service = described_class.new(cep: "76820172")

      allow(service).to receive(:company_account).and_return(admin)
      allow(service).to receive(:fetch_via_cep).with("76804320").and_return({ "localidade" => "Porto Velho", "uf" => "RO" })
      allow(service).to receive(:geocode_cep!).with("76820172").and_return({ lat: -8.759, lng: -63.903 })
      allow(service).to receive(:parse_coordinates).and_return(nil, nil, { lat: -8.761, lng: -63.902 })

      quote = service.call

      expect(quote[:distance_km]).to be >= 0
      expect(quote[:fee_cents]).to be >= described_class::MIN_FEE_CENTS
    end

    it "returns zero fee when subtotal reaches minimum delivery order" do
      admin = User.create!(
        name: "Admin Delivery Min",
        email: "admin-delivery-min-#{SecureRandom.hex(4)}@example.com",
        role: :admin,
        password: "password123",
        company_address: "Endereco sem geocoding",
        company_cep: "76804-320",
        company_delivery_min_order_cents: 5000
      )

      service = described_class.new(cep: "76820172", subtotal_cents: 5000)

      allow(service).to receive(:company_account).and_return(admin)
      allow(service).to receive(:fetch_via_cep).with("76804320").and_return({ "localidade" => "Porto Velho", "uf" => "RO" })
      allow(service).to receive(:geocode_cep!).with("76820172").and_return({ lat: -8.759, lng: -63.903 })
      allow(service).to receive(:parse_coordinates).and_return(nil, nil, { lat: -8.761, lng: -63.902 })

      quote = service.call

      expect(quote[:fee_cents]).to eq(0)
    end
  end
end
