require "net/http"
require "json"

class SessionsController < ApplicationController
  def new
    if current_customer
      redirect_to(session.delete(:return_to) || products_path)
      return
    end

    prepare_forms
  end

  def create
    email = login_params[:email].to_s.downcase.strip
    user = User.customer.find_by(email: email)

    if user&.authenticate(login_params[:password].to_s)
      session[:customer_user_id] = user.id
      redirect_to(session.delete(:return_to) || cart_path, notice: "Login realizado com sucesso.")
    else
      @login_email = email
      prepare_forms
      flash.now[:alert] = "Email ou senha inválidos."
      render :new, status: :unprocessable_entity
    end
  end

  def signup
    user = User.customer.new(signup_params)
    user.email = user.email.to_s.downcase.strip

    if user.save
      session[:customer_user_id] = user.id
      redirect_to(session.delete(:return_to) || cart_path, notice: "Conta criada com sucesso.")
    else
      @signup_name = user.name
      @signup_email = user.email
      @login_email = user.email
      prepare_forms
      flash.now[:alert] = user.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  def google_start
    unless google_oauth_configured?
      redirect_to customer_login_path, alert: "Login Google não configurado."
      return
    end

    state = SecureRandom.hex(24)
    session[:google_oauth_state] = state

    query = {
      client_id: ENV.fetch("GOOGLE_CLIENT_ID"),
      redirect_uri: customer_google_callback_url,
      response_type: "code",
      scope: "openid email profile",
      access_type: "offline",
      include_granted_scopes: "true",
      prompt: "select_account",
      state: state
    }

    redirect_to "https://accounts.google.com/o/oauth2/v2/auth?#{query.to_query}", allow_other_host: true
  end

  def google_callback
    if params[:error].present?
      redirect_to customer_login_path, alert: "Não foi possível entrar com Google (#{params[:error]})."
      return
    end

    unless google_oauth_configured?
      redirect_to customer_login_path, alert: "Login Google não configurado."
      return
    end

    if params[:state].blank? || params[:state] != session.delete(:google_oauth_state)
      redirect_to customer_login_path, alert: "Falha de segurança na autenticação Google. Tente novamente."
      return
    end

    if params[:code].blank?
      redirect_to customer_login_path, alert: "Código de autenticação Google inválido."
      return
    end

    token_payload = exchange_google_code_for_token(params[:code])
    access_token = token_payload["access_token"].to_s
    profile_payload = fetch_google_profile(access_token)

    email = profile_payload["email"].to_s.downcase
    uid = profile_payload["sub"].to_s
    name = profile_payload["name"].to_s.strip

    if email.blank? || uid.blank?
      redirect_to customer_login_path, alert: "Não foi possível recuperar sua conta Google."
      return
    end

    user = User.customer.find_by(provider: "google_oauth2", uid: uid) ||
           User.customer.find_by(email: email) ||
           User.customer.new

    user.provider = "google_oauth2"
    user.uid = uid
    user.email = email
    user.name = name.presence || email.split("@").first.titleize

    if user.password_digest.blank?
      temporary_password = SecureRandom.hex(24)
      user.password = temporary_password
      user.password_confirmation = temporary_password
    end

    user.save!
    session[:customer_user_id] = user.id
    redirect_to(session.delete(:return_to) || cart_path, notice: "Login com Google realizado com sucesso.")
  rescue ActiveRecord::RecordInvalid => e
    redirect_to customer_login_path, alert: e.record.errors.full_messages.to_sentence
  rescue StandardError
    redirect_to customer_login_path, alert: "Não foi possível concluir login com Google."
  end

  def destroy
    session.delete(:customer_user_id)
    redirect_to products_path, notice: "Sessão encerrada."
  end

  private

  def login_params
    params.permit(:email, :password)
  end

  def signup_params
    params.permit(:name, :email, :password, :password_confirmation)
  end

  def prepare_forms
    @login_email ||= ""
    @signup_name ||= ""
    @signup_email ||= ""
  end

  def google_oauth_configured?
    ENV["GOOGLE_CLIENT_ID"].present? && ENV["GOOGLE_CLIENT_SECRET"].present?
  end

  def exchange_google_code_for_token(code)
    uri = URI("https://oauth2.googleapis.com/token")
    response = Net::HTTP.post_form(uri, {
      code: code,
      client_id: ENV.fetch("GOOGLE_CLIENT_ID"),
      client_secret: ENV.fetch("GOOGLE_CLIENT_SECRET"),
      redirect_uri: customer_google_callback_url,
      grant_type: "authorization_code"
    })

    JSON.parse(response.body).tap do |payload|
      raise "google_token_exchange_failed" unless response.is_a?(Net::HTTPSuccess)
      raise "google_access_token_missing" if payload["access_token"].blank?
    end
  end

  def fetch_google_profile(access_token)
    uri = URI("https://openidconnect.googleapis.com/v1/userinfo")
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{access_token}"

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      http.request(request)
    end
    payload = JSON.parse(response.body)

    raise "google_profile_fetch_failed" unless response.is_a?(Net::HTTPSuccess)
    raise "google_email_unverified" unless payload["email_verified"].to_s == "true"
    raise "google_sub_missing" if payload["sub"].blank?

    payload
  end
end
