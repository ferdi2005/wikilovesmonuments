class AddDuplicateToMonuments < ActiveRecord::Migration[5.2]
  def change
    add_column :monuments, :duplicate, :boolean, default: false
  end
end
