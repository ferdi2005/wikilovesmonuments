class ChangeColumnsToTextInMonuments < ActiveRecord::Migration[7.0]
  def up
    change_column :monuments, :uploadurl, :text
    change_column :monuments, :nonwlmuploadurl, :text
    change_column :monuments, :image, :text
    change_column :monuments, :commons, :text
    change_column :monuments, :allphotos, :text
    change_column :monuments, :wikipedia, :text
    change_column :monuments, :address, :text
  end

  def down
    change_column :monuments, :uploadurl, :string
    change_column :monuments, :nonwlmuploadurl, :string
    change_column :monuments, :image, :string
    change_column :monuments, :commons, :string
    change_column :monuments, :allphotos, :string
    change_column :monuments, :wikipedia, :string
    change_column :monuments, :address, :string
  end
end
