# frozen_string_literal: true

class AddDeviseToUsers < ActiveRecord::Migration[7.1]
  def up
    add_column :users, :encrypted_password, :string, null: false, default: "" unless column_exists?(:users, :encrypted_password)
    add_column :users, :reset_password_token, :string unless column_exists?(:users, :reset_password_token)
    add_column :users, :reset_password_sent_at, :datetime unless column_exists?(:users, :reset_password_sent_at)
    add_column :users, :remember_created_at, :datetime unless column_exists?(:users, :remember_created_at)

    execute <<~SQL.squish
      UPDATE users
      SET encrypted_password = password_digest
      WHERE COALESCE(encrypted_password, '') = '' AND COALESCE(password_digest, '') <> ''
    SQL

    change_column_null :users, :password_digest, true if column_exists?(:users, :password_digest)

    add_index :users, :reset_password_token, unique: true unless index_exists?(:users, :reset_password_token)
  end

  def down
    if column_exists?(:users, :password_digest)
      execute <<~SQL.squish
        UPDATE users
        SET password_digest = encrypted_password
        WHERE COALESCE(password_digest, '') = '' AND COALESCE(encrypted_password, '') <> ''
      SQL
      change_column_null :users, :password_digest, false
    end

    remove_index :users, :reset_password_token if index_exists?(:users, :reset_password_token)
    remove_column :users, :remember_created_at if column_exists?(:users, :remember_created_at)
    remove_column :users, :reset_password_sent_at if column_exists?(:users, :reset_password_sent_at)
    remove_column :users, :reset_password_token if column_exists?(:users, :reset_password_token)
    remove_column :users, :encrypted_password if column_exists?(:users, :encrypted_password)
  end
end
