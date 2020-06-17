class AddWikipediaToMonuments < ActiveRecord::Migration[5.2]
  def change
    add_column :monuments, :wikipedia, :string
  end
end
