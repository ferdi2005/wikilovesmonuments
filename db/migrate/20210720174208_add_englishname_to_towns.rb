class AddEnglishnameToTowns < ActiveRecord::Migration[5.2]
  def change
    add_column :towns, :english_name, :string
  end
end
