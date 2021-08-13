class AddCitiesToNophotos < ActiveRecord::Migration[5.2]
  def change
    add_column :nophotos, :cities, :integer
    add_column :nophotos, :cities_with_trees, :integer
  end
end
