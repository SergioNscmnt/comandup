class CreateOrders < ActiveRecord::Migration[7.1]
  def change
    create_table :orders do |t|
      t.references :customer, null: false, foreign_key: { to_table: :users }
      t.integer :status, null: false, default: 0
      t.integer :subtotal_cents, null: false, default: 0
      t.integer :discount_cents, null: false, default: 0
      t.integer :total_cents, null: false, default: 0
      t.integer :eta_minutes
      t.integer :queue_position
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end

    add_index :orders, [:status, :created_at]
    add_index :orders, [:customer_id, :created_at]
    add_check_constraint :orders, "status IN (0, 1, 2, 3, 4, 5, 6)", name: "chk_orders_status"
    add_check_constraint :orders, "subtotal_cents >= 0", name: "chk_orders_subtotal_cents"
    add_check_constraint :orders, "discount_cents >= 0", name: "chk_orders_discount_cents"
    add_check_constraint :orders, "total_cents >= 0", name: "chk_orders_total_cents"
  end
end
