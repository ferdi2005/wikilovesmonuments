class AddHiddenToMonuments < ActiveRecord::Migration[5.2]
  def change
    add_column :monuments, :hidden, :boolean
  end
end
