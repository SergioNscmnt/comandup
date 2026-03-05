require "rails_helper"

RSpec.describe ComboItem, type: :model do
  def create_category!(suffix: SecureRandom.hex(4))
    Category.create!(name: "Categoria #{suffix}")
  end

  def create_product!(suffix: SecureRandom.hex(4))
    Product.create!(
      name: "Produto #{suffix}",
      category: create_category!(suffix: suffix),
      price_cents: 1200,
      prep_minutes: 10
    )
  end

  def create_combo!(suffix: SecureRandom.hex(4))
    Combo.create!(name: "Combo #{suffix}", price_cents: 2500)
  end

  it "is valid with combo, product and positive quantity" do
    combo_item = described_class.new(combo: create_combo!, product: create_product!, quantity: 2)

    expect(combo_item).to be_valid
  end

  it "requires quantity greater than zero" do
    combo_item = described_class.new(combo: create_combo!, product: create_product!, quantity: 0)

    expect(combo_item).not_to be_valid
    expect(combo_item.errors[:quantity]).to be_present
  end
end
