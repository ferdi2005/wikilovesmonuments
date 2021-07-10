class AddTreeToMonuments < ActiveRecord::Migration[5.2]
  def change
    add_column :monuments, :tree, :boolean, default: false
  end
end
