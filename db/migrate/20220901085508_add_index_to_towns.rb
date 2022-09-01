class AddIndexToTowns < ActiveRecord::Migration[7.0]
  def change
    add_index :towns, :name
    add_index :towns, :english_name
  end
end
