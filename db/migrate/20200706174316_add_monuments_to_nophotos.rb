class AddMonumentsToNophotos < ActiveRecord::Migration[5.2]
  def change
    add_column :nophotos, :monuments, :integer
  end
end
