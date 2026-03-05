class AddImageUrlToCombos < ActiveRecord::Migration[7.1]
  def change
    add_column :combos, :image_url, :string
  end
end
