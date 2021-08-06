class AddCityItemToMonuments < ActiveRecord::Migration[5.2]
  def change
    add_column :monuments, :city_item, :string
  end
end
