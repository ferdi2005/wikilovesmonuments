class CreateNophotos < ActiveRecord::Migration[5.2]
  def change
    create_table :nophotos do |t|
      t.integer :count

      t.timestamps
    end
  end
end
