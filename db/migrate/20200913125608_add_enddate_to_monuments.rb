class AddEnddateToMonuments < ActiveRecord::Migration[5.2]
  def change
    add_column :monuments, :enddate, :datetime
  end
end
