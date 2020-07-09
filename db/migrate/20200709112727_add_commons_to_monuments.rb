class AddCommonsToMonuments < ActiveRecord::Migration[5.2]
  def change
    add_column :monuments, :commons, :string
  end
end
