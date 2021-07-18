class AddUniqueIndexToTowns < ActiveRecord::Migration[5.2]
  def change
    add_index :towns, [:name, :disambiguation], unique: true
  end
end
