class AddItemToTowns < ActiveRecord::Migration[5.2]
  def change
    add_column :towns, :item, :string
  end
end
