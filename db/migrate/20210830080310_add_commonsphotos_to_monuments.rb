class AddCommonsphotosToMonuments < ActiveRecord::Migration[5.2]
  def change
    add_column :monuments, :commonsphotos, :integer
  end
end
