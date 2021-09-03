class AddIndexToMonumentsItem < ActiveRecord::Migration[6.1]
  def change
    add_index :monuments, :item, unique: true
  end
end
