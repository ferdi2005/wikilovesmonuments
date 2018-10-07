class CreateMonuments < ActiveRecord::Migration[5.2]
  def change
    create_table :monuments do |t|
      t.string :item
      t.string :wlmid
      t.decimal :latitude, precision: 2, scale: 15
      t.decimal :longitude, precision: 2, scale: 15
      t.string :itemLabel
      t.string :image

      t.timestamps
    end
  end
end
