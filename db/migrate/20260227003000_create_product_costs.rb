class CreateProductCosts < ActiveRecord::Migration[7.1]
  def change
    create_table :product_costs do |t|
      t.references :product, null: false, foreign_key: true, index: { unique: true }
      t.integer :ingredients_cents, null: false, default: 0
      t.integer :packaging_cents, null: false, default: 0
      t.decimal :losses_percent, precision: 5, scale: 2, null: false, default: 0.0
      t.integer :labor_cents, null: false, default: 0
      t.integer :fixed_allocation_cents, null: false, default: 0
      t.decimal :channel_fee_percent, precision: 5, scale: 2, null: false, default: 0.0
      t.timestamps
    end
  end
end
