module Users
  class PasswordsController < Devise::PasswordsController
    layout "application"

    def create
      normalized_email = params.dig(resource_name, :email).to_s.downcase.strip
      params[resource_name] ||= {}
      params[resource_name][:email] = normalized_email

      self.resource = resource_class.send_reset_password_instructions(resource_params)
      notice_message = "Se o email existir na base, você receberá instruções para redefinir a senha."

      if successfully_sent?(resource)
        redirect_to customer_login_path, notice: notice_message
      else
        flash.now[:alert] = resource.errors.full_messages.to_sentence
        render :new, status: :unprocessable_entity
      end
    end

    protected

    def after_resetting_password_path_for(_resource)
      customer_login_path
    end

    def after_sending_reset_password_instructions_path_for(_resource_name)
      customer_login_path
    end
  end
end
