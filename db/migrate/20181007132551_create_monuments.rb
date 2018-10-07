class CreateMonuments < ActiveRecord::Migration[5.2]
  def change
    create_table :monuments do |t|
      t.string :item
      t.string :wlmid
      t.decimal :latitude
      t.decimal :longitude
      t.string :itemLabel
      t.string :image

      t.timestamps
    end
  end
end
