class AddRegioneToNophotos < ActiveRecord::Migration[5.2]
  def change
    add_column :nophotos, :regione, :string
  end
end
