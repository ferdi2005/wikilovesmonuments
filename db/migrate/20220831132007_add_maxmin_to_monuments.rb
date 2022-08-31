class AddMaxminToMonuments < ActiveRecord::Migration[7.0]
  def change
    add_column :monuments, :presumed_maxlat, :decimal
    add_column :monuments, :presumed_minlat, :decimal
    add_column :monuments, :presumed_maxlon, :decimal
    add_column :monuments, :presumed_minlon, :decimal
  end
end
