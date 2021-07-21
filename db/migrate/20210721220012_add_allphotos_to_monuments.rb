class AddAllphotosToMonuments < ActiveRecord::Migration[5.2]
  def change
    add_column :monuments, :allphotos, :string
  end
end
