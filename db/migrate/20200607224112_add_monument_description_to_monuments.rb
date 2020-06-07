class AddMonumentDescriptionToMonuments < ActiveRecord::Migration[5.2]
  def change
    add_column :monuments, :itemDescription, :string
  end
end
