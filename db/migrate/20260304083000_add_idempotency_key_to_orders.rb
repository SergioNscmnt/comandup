class AddIdempotencyKeyToOrders < ActiveRecord::Migration[7.1]
  def change
    add_column :orders, :idempotency_key, :string
    add_index :orders, :idempotency_key, unique: true
  end
end
