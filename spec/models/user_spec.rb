require "rails_helper"

RSpec.describe User, type: :model do
  def build_customer(email: "USER.#{SecureRandom.hex(4)}@EXAMPLE.COM")
    described_class.new(
      name: "Cliente Teste",
      email: email,
      role: :customer,
      password: "segredo123",
      password_confirmation: "segredo123"
    )
  end

  it "normalizes email before validation" do
    user = build_customer(email: "  USER.TESTE@EXAMPLE.COM  ")
    user.validate

    expect(user.email).to eq("user.teste@example.com")
  end

  it "requires uid when provider is present" do
    user = build_customer
    user.provider = "google_oauth2"
    user.uid = nil

    expect(user).not_to be_valid
    expect(user.errors[:uid]).to be_present
  end

  it "returns first admin as company_account" do
    admin_one = described_class.admin.create!(
      name: "Admin 1",
      email: "admin1.#{SecureRandom.hex(4)}@example.com",
      password: "segredo123",
      password_confirmation: "segredo123"
    )
    described_class.admin.create!(
      name: "Admin 2",
      email: "admin2.#{SecureRandom.hex(4)}@example.com",
      password: "segredo123",
      password_confirmation: "segredo123"
    )

    expect(described_class.company_account).to eq(admin_one)
  end
end
