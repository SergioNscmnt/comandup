class AddCompanyOperationalFieldsToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :company_delivery_radius_km, :decimal, precision: 8, scale: 2
    add_column :users, :company_delivery_fee_per_km_cents, :integer
    add_column :users, :company_delivery_min_fee_cents, :integer
    add_column :users, :company_delivery_min_order_cents, :integer
    add_column :users, :company_prep_minutes_base, :integer
  end
end
