class AddUploadToMonuments < ActiveRecord::Migration[5.2]
  def change
    add_column :monuments, :uploadurl, :string
    add_column :monuments, :regione, :string
  end
end
