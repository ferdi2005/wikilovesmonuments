class AddAddressToMonuments < ActiveRecord::Migration[5.2]
  def change
    add_column :monuments, :address, :string
  end
end
