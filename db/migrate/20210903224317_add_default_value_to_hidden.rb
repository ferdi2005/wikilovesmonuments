class AddDefaultValueToHidden < ActiveRecord::Migration[6.1]
  def change
    change_column_default :monuments, :hidden, false
  end
end
