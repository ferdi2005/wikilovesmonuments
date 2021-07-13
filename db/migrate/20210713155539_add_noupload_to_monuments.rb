class AddNouploadToMonuments < ActiveRecord::Migration[5.2]
  def change
    add_column :monuments, :noupload, :boolean, default: false
  end
end
