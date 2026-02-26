class AddAdminCatalogFields < ActiveRecord::Migration[7.1]
  def change
    add_column :combos, :description, :text

    add_column :promotions, :discount_kind, :integer, default: 0, null: false
    add_column :promotions, :discount_value_cents, :integer, default: 0, null: false
    add_column :promotions, :quantity, :integer
    add_column :promotions, :coupon_category, :string, default: "all", null: false
  end
end
