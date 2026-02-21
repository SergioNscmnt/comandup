module Admin
  class BaseController < ApplicationController
    before_action :require_admin_session!

    private

    def require_admin_session!
      return if current_admin

      redirect_to admin_login_path
    end
  end
end
