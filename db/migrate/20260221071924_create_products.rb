class CreateProducts < ActiveRecord::Migration[7.1]
  def change
    create_table :products do |t|
      t.string :name, null: false
      t.text :description
      t.integer :price_cents, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.integer :prep_minutes, null: false, default: 10

      t.timestamps
    end

    add_check_constraint :products, "price_cents >= 0", name: "chk_products_price_cents"
    add_check_constraint :products, "prep_minutes > 0", name: "chk_products_prep_minutes"
    add_index :products, :active
  end
end
