class CreateOrderItems < ActiveRecord::Migration[7.1]
  def change
    create_table :order_items do |t|
      t.references :order, null: false, foreign_key: true
      t.references :product, null: true, foreign_key: true
      t.references :combo, null: true, foreign_key: true
      t.integer :quantity, null: false, default: 1
      t.integer :unit_price_cents, null: false, default: 0
      t.integer :total_cents, null: false, default: 0

      t.timestamps
    end

    add_check_constraint :order_items, "quantity > 0", name: "chk_order_items_quantity"
    add_check_constraint :order_items, "unit_price_cents >= 0", name: "chk_order_items_unit_price"
    add_check_constraint :order_items, "total_cents >= 0", name: "chk_order_items_total"
  end
end
