require "rails_helper"

RSpec.describe "Account area", type: :request do
  before { host! "localhost" }

  let!(:customer) do
    unique_email = "cliente.conta.#{SecureRandom.hex(4)}@example.com"

    User.customer.create!(
      name: "Cliente Teste",
      email: unique_email,
      password: "segredo123",
      password_confirmation: "segredo123"
    )
  end

  it "requires authentication to access account page" do
    get account_path

    expect(response).to redirect_to(customer_login_path)
  end

  it "shows account data for logged customer" do
    get account_path, headers: { "HTTP_X_CUSTOMER_ID" => customer.id.to_s }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Perfil do cliente")
    expect(response.body).to include(customer.email)
  end
end
