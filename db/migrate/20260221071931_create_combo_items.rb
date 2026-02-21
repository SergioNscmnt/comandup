class CreateComboItems < ActiveRecord::Migration[7.1]
  def change
    create_table :combo_items do |t|
      t.references :combo, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.integer :quantity, null: false, default: 1

      t.timestamps
    end

    add_check_constraint :combo_items, "quantity > 0", name: "chk_combo_items_quantity"
    add_index :combo_items, [:combo_id, :product_id], unique: true
  end
end
