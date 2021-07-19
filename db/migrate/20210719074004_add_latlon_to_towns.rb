class AddLatlonToTowns < ActiveRecord::Migration[5.2]
  def change
    add_column :towns, :latitude, :decimal
    add_column :towns, :longitude, :decimal
  end
end
