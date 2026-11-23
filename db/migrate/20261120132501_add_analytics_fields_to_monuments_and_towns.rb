class AddAnalyticsFieldsToMonumentsAndTowns < ActiveRecord::Migration[7.0]
  def change
    add_column :towns, :population, :integer
    add_index :towns, :item unless index_exists?(:towns, :item)

    add_column :monuments, :instanceof_qid, :string
    add_column :monuments, :monument_type, :string
    add_column :monuments, :inception_year, :integer
    add_column :monuments, :mic_catalog_id, :string
  end
end
