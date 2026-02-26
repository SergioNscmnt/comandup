require "rails_helper"

RSpec.describe "Customer authentication", type: :request do
  describe "POST /signup" do
    it "creates a customer account and signs in" do
      expect do
        post customer_signup_path, params: {
          name: "Maria Silva",
          email: "maria@example.com",
          password: "segredo123",
          password_confirmation: "segredo123"
        }
      end.to change(User.customer, :count).by(1)

      expect(response).to redirect_to(cart_path)
      follow_redirect!
      expect(response.body).to include("Conta criada com sucesso.")
    end
  end

  describe "POST /login" do
    let!(:customer) do
      User.customer.create!(
        name: "Joao Cliente",
        email: "joao@example.com",
        password: "segredo123",
        password_confirmation: "segredo123"
      )
    end

    it "signs in with valid credentials" do
      post customer_session_path, params: { email: customer.email, password: "segredo123" }

      expect(response).to redirect_to(cart_path)
      follow_redirect!
      expect(response.body).to include("Login realizado com sucesso.")
    end

    it "returns unprocessable entity with invalid credentials" do
      post customer_session_path, params: { email: customer.email, password: "senhaerrada" }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Email ou senha inválidos.")
    end
  end

  describe "POST /recuperar-senha" do
    let!(:customer) do
      User.customer.create!(
        name: "Ana Cliente",
        email: "ana@example.com",
        password: "segredo123",
        password_confirmation: "segredo123"
      )
    end

    it "sends reset password instructions and redirects to login" do
      expect do
        post user_password_path, params: { user: { email: customer.email } }
      end.to change(ActionMailer::Base.deliveries, :count).by(1)

      expect(response).to redirect_to(customer_login_path)
      follow_redirect!
      expect(response.body).to include("você receberá instruções para redefinir a senha")
    end
  end
end
