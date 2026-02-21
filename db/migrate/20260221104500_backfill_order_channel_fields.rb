class BackfillOrderChannelFields < ActiveRecord::Migration[7.1]
  class MigrationOrder < ApplicationRecord
    self.table_name = "orders"
  end

  def up
    MigrationOrder.where(service_token: [nil, ""]).find_each do |order|
      order.update_columns(service_token: SecureRandom.hex(16))
    end

    MigrationOrder.where(order_type: 0, table_number: [nil, ""]).update_all(table_number: "MESA-LEGADO")
  end

  def down
    # no-op
  end
end
