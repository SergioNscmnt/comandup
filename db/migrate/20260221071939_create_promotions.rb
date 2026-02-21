class CreatePromotions < ActiveRecord::Migration[7.1]
  def change
    create_table :promotions do |t|
      t.string :name, null: false
      t.decimal :discount_percent, precision: 5, scale: 2, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.datetime :starts_at
      t.datetime :ends_at

      t.timestamps
    end

    add_check_constraint :promotions, "discount_percent >= 0 AND discount_percent <= 100", name: "chk_promotions_discount_percent"
    add_index :promotions, :active
  end
end
