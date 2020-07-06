class AddPhotosCountToMonuments < ActiveRecord::Migration[5.2]
  def change
    add_column :monuments, :photos_count, :integer
  end
end
