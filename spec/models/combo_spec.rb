require "rails_helper"

RSpec.describe Combo, type: :model do
  it "is valid with name and non-negative price" do
    combo = described_class.new(name: "Combo Casa", price_cents: 1990)

    expect(combo).to be_valid
  end

  it "requires name" do
    combo = described_class.new(name: nil, price_cents: 1990)

    expect(combo).not_to be_valid
    expect(combo.errors[:name]).to be_present
  end

  it "validates image_url format" do
    invalid_combo = described_class.new(name: "Invalido", price_cents: 1000, image_url: "ftp://arquivo")
    valid_combo = described_class.new(name: "Valido", price_cents: 1000, image_url: "https://example.com/img.png")

    expect(invalid_combo).not_to be_valid
    expect(valid_combo).to be_valid
  end
end
