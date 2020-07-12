class RenameColumnsInMonuments < ActiveRecord::Migration[5.2]
  def change
    rename_column :monuments, :itemLabel, :itemlabel
    rename_column :monuments, :itemDescription, :itemdescription
  end
end
