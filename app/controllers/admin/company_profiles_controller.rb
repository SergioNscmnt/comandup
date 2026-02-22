module Admin
  class CompanyProfilesController < BaseController
    def edit
      @company_account = company_account
    end

    def update
      @company_account = company_account

      if @company_account.update(company_profile_params)
        redirect_to edit_admin_company_profile_path, notice: "Endereço da empresa atualizado."
      else
        flash.now[:alert] = @company_account.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def company_account
      User.company_account || current_admin
    end

    def company_profile_params
      params.require(:user).permit(:company_address, :company_cep)
    end
  end
end
