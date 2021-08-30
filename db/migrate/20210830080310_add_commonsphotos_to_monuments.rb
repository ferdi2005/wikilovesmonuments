class AddCommonsphotosToMonuments < ActiveRecord::Migration[5.2]
  def change
    add_column :commonsphotos, :monuments, :integer
  end
end
