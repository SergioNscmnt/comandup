module Admin
  class SessionsController < ApplicationController
    layout "application"

    def new
      return redirect_to admin_queue_path if current_admin
    end

    def create
      user = User.admin.find_by(email: params[:email].to_s.downcase.strip)

      if user&.valid_password?(params[:password].to_s)
        sign_in(user)
        redirect_to admin_queue_path
      else
        flash.now[:alert] = "Email ou senha inválidos"
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      sign_out(:user)
      redirect_to admin_login_path
    end
  end
end
