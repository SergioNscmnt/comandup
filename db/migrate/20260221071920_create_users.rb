class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.integer :role, null: false, default: 0
      t.string :password_digest, null: false

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_check_constraint :users, "role IN (0, 1)", name: "chk_users_role"
  end
end
