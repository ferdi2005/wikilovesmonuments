class AddCommonsToTowns < ActiveRecord::Migration[7.0]
  def change
    add_column :towns, :commons, :string
  end
end
