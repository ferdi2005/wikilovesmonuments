class AddWithPhotosToMonuments < ActiveRecord::Migration[5.2]
  def change
    add_column :monuments, :with_photos, :boolean
  end
end
