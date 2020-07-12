class AddOthercountsToNophotos < ActiveRecord::Migration[5.2]
  def change
    add_column :nophotos, :with_commons, :integer
    add_column :nophotos, :with_image, :integer
  end
end
