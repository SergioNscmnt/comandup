class CreateAuditLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :audit_logs do |t|
      t.references :order, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.string :event, null: false
      t.integer :from_status
      t.integer :to_status
      t.string :reason
      t.json :metadata

      t.timestamps
    end

    add_index :audit_logs, [:order_id, :created_at]
    add_index :audit_logs, [:user_id, :created_at]
  end
end
