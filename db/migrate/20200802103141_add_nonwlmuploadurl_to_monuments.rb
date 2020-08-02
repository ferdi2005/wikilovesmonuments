class AddNonwlmuploadurlToMonuments < ActiveRecord::Migration[5.2]
  def change
    add_column :monuments, :nonwlmuploadurl, :string
  end
end
