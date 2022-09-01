class AddIndexToMonuments < ActiveRecord::Migration[7.0]
  def change
    add_index :monuments, :itemlabel
    add_index :monuments, :itemdescription
  end
end
