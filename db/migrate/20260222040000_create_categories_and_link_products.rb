class CreateCategoriesAndLinkProducts < ActiveRecord::Migration[7.1]
  class CategoryRecord < ActiveRecord::Base
    self.table_name = "categories"
  end

  class ProductRecord < ActiveRecord::Base
    self.table_name = "products"
  end

  def up
    create_table :categories do |t|
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :categories, :name, unique: true
    add_index :categories, :position

    add_reference :products, :category, foreign_key: true

    create_default_categories
    backfill_products_category

    change_column_null :products, :category_id, false
  end

  def down
    remove_reference :products, :category, foreign_key: true
    drop_table :categories
  end

  private

  def create_default_categories
    names = [
      "Lanches",
      "Porcoes",
      "Bebidas",
      "Sobremesas",
      "Outros"
    ]

    names.each_with_index do |name, index|
      CategoryRecord.find_or_create_by!(name: name) do |category|
        category.position = index + 1
      end
    end
  end

  def backfill_products_category
    categories = CategoryRecord.all.index_by(&:name)

    ProductRecord.find_each do |product|
      normalized_name = product.name.to_s.downcase

      category_name =
        if normalized_name.start_with?("x-") || normalized_name.include?("burger") || normalized_name.include?("sandu")
          "Lanches"
        elsif normalized_name.include?("batata") || normalized_name.include?("onion") || normalized_name.include?("porcao")
          "Porcoes"
        elsif normalized_name.include?("refrigerante") || normalized_name.include?("suco") || normalized_name.include?("agua")
          "Bebidas"
        elsif normalized_name.include?("milkshake") || normalized_name.include?("sobremesa")
          "Sobremesas"
        else
          "Outros"
        end

      product.update_columns(category_id: categories.fetch(category_name).id)
    end
  end
end
