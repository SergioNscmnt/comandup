class AddOrderChannelsAndTracking < ActiveRecord::Migration[7.1]
  def change
    add_column :orders, :order_type, :integer, null: false, default: 0
    add_column :orders, :table_number, :string
    add_column :orders, :delivery_address, :string
    add_column :orders, :service_token, :string

    add_column :orders, :received_at, :datetime
    add_column :orders, :started_at, :datetime
    add_column :orders, :ready_at, :datetime
    add_column :orders, :delivered_at, :datetime
    add_column :orders, :canceled_at, :datetime

    add_index :orders, :order_type
    add_index :orders, :table_number
    add_index :orders, :service_token, unique: true
    add_index :orders, [:order_type, :status, :created_at], name: "idx_orders_type_status_created"
  end
end
