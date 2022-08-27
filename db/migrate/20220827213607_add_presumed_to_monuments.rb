class AddPresumedToMonuments < ActiveRecord::Migration[7.0]
  def change
    add_column :monuments, :presumed_latitude, :decimal
    add_column :monuments, :presumed_longitude, :decimal
  end
end
