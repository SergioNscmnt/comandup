class CreatePayments < ActiveRecord::Migration[7.1]
  def change
    create_table :payments do |t|
      t.references :order, null: false, foreign_key: true
      t.integer :status, null: false, default: 0
      t.integer :amount_cents, null: false, default: 0
      t.string :provider, null: false, default: "mock"
      t.string :provider_reference
      t.string :provider_event_id
      t.datetime :approved_at
      t.string :refused_reason
      t.json :raw_payload

      t.timestamps
    end

    add_index :payments, :provider_event_id, unique: true
    add_check_constraint :payments, "status IN (0, 1, 2, 3)", name: "chk_payments_status"
    add_check_constraint :payments, "amount_cents >= 0", name: "chk_payments_amount"
  end
end
