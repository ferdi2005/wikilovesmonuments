class AddYearToMonuments < ActiveRecord::Migration[5.2]
  def change
    add_column :monuments, :year, :date
  end
end
