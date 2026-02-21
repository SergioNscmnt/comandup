class AllowOrdersWithoutCustomer < ActiveRecord::Migration[7.1]
  def change
    change_column_null :orders, :customer_id, true
  end
end
