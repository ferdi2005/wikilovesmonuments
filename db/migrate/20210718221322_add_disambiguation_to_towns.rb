class AddDisambiguationToTowns < ActiveRecord::Migration[5.2]
  def change
    add_column :towns, :disambiguation, :string
    add_column :towns, :visible_name, :string
    add_column :towns, :search_name, :string
  end
end
