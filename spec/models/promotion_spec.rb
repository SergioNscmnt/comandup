require "rails_helper"

RSpec.describe Promotion, type: :model do
  def build_percentage_promotion(**attrs)
    defaults = {
      name: "Promo Percentual #{SecureRandom.hex(3)}",
      discount_kind: :percentage,
      discount_percent: 10,
      coupon_category: "all",
      active: true
    }

    described_class.new(defaults.merge(attrs))
  end

  it "is invalid when ends_at is before starts_at" do
    promotion = build_percentage_promotion(starts_at: Time.current, ends_at: 1.hour.ago)

    expect(promotion).not_to be_valid
    expect(promotion.errors[:ends_at]).to be_present
  end

  it "requires discount_value_cents for fixed_value" do
    promotion = described_class.new(
      name: "Promo Fixa",
      discount_kind: :fixed_value,
      discount_value_cents: -1,
      coupon_category: "all",
      active: true
    )

    expect(promotion).not_to be_valid
    expect(promotion.errors[:discount_value_cents]).to be_present
  end

  it "returns only active promotions inside window and with quantity" do
    active = Promotion.create!(
      name: "Ativa #{SecureRandom.hex(3)}",
      discount_kind: :percentage,
      discount_percent: 10,
      coupon_category: "all",
      active: true,
      starts_at: 1.hour.ago,
      ends_at: 1.hour.from_now,
      quantity: 3
    )
    Promotion.create!(
      name: "Inativa #{SecureRandom.hex(3)}",
      discount_kind: :percentage,
      discount_percent: 10,
      coupon_category: "all",
      active: false,
      starts_at: 1.hour.ago,
      ends_at: 1.hour.from_now,
      quantity: 3
    )

    expect(Promotion.active_now).to include(active)
    expect(Promotion.active_now.count).to eq(1)
  end
end
