class AddIscastleToMonuments < ActiveRecord::Migration[6.1]
  def change
    add_column :monuments, :is_castle, :bool, default: false
  end
end
