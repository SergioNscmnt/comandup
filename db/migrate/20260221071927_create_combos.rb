class CreateCombos < ActiveRecord::Migration[7.1]
  def change
    create_table :combos do |t|
      t.string :name, null: false
      t.integer :price_cents, null: false, default: 0
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_check_constraint :combos, "price_cents >= 0", name: "chk_combos_price_cents"
    add_index :combos, :active
  end
end
