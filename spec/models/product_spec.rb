require "rails_helper"

RSpec.describe Product, type: :model do
  def create_category!(suffix: SecureRandom.hex(4))
    Category.create!(name: "Categoria #{suffix}")
  end

  it "is valid with required attributes" do
    product = described_class.new(
      name: "X-Burger",
      category: create_category!,
      price_cents: 2590,
      prep_minutes: 12
    )

    expect(product).to be_valid
  end

  it "requires category" do
    product = described_class.new(name: "Sem categoria", price_cents: 1000, prep_minutes: 10)

    expect(product).not_to be_valid
    expect(product.errors[:category]).to be_present
  end

  it "validates image_url format" do
    invalid_product = described_class.new(name: "Invalido", category: create_category!, price_cents: 1000, prep_minutes: 10, image_url: "file://local")
    valid_product = described_class.new(name: "Valido", category: create_category!, price_cents: 1000, prep_minutes: 10, image_url: "https://example.com/produto.png")

    expect(invalid_product).not_to be_valid
    expect(valid_product).to be_valid
  end
end
