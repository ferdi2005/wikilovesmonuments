class AddCityToMonuments < ActiveRecord::Migration[5.2]
  def change
    add_column :monuments, :city, :string
  end
end
