class AddNotesToOrderItems < ActiveRecord::Migration[7.1]
  def change
    add_column :order_items, :notes, :string
  end
end
