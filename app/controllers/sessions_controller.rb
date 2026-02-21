class SessionsController < ApplicationController
  def new
    redirect_to(session.delete(:return_to) || products_path) if current_customer
  end

  def create_google
    email = params[:email].to_s.downcase.strip
    name = params[:name].to_s.strip

    if email.blank?
      redirect_to customer_login_path, alert: "Informe um e-mail para entrar."
      return
    end

    uid = "google-#{Digest::SHA256.hexdigest(email)}"
    user = User.customer.find_or_initialize_by(provider: "google_oauth2", uid: uid)
    user.email = email
    user.name = name.presence || email.split("@").first.titleize

    if user.password_digest.blank?
      temporary_password = SecureRandom.hex(24)
      user.password = temporary_password
      user.password_confirmation = temporary_password
    end

    user.save!
    session[:customer_user_id] = user.id
    redirect_to(session.delete(:return_to) || cart_path, notice: "Login realizado com sucesso.")
  rescue ActiveRecord::RecordInvalid => e
    redirect_to customer_login_path, alert: e.record.errors.full_messages.to_sentence
  end

  def destroy
    session.delete(:customer_user_id)
    redirect_to products_path, notice: "Sessão encerrada."
  end
end
