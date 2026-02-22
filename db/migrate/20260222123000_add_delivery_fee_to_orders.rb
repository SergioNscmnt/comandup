class AddDeliveryFeeToOrders < ActiveRecord::Migration[7.1]
  def change
    add_column :orders, :delivery_fee_cents, :integer, null: false, default: 0
    add_column :orders, :delivery_distance_km, :decimal, precision: 8, scale: 2

    add_check_constraint :orders, "delivery_fee_cents >= 0", name: "chk_orders_delivery_fee_cents"
    add_check_constraint :orders, "delivery_distance_km is null or delivery_distance_km >= 0", name: "chk_orders_delivery_distance_km"
  end
end
