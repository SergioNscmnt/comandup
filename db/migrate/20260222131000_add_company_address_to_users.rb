class AddCompanyAddressToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :company_address, :string
    add_column :users, :company_cep, :string
  end
end
