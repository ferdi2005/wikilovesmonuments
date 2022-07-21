class AddQualityToMonuments < ActiveRecord::Migration[7.0]
  def change
    add_column :monuments, :quality, :boolean, default: false
    add_column :monuments, :featured, :boolean, default: false
    add_column :monuments, :quality_count, :integer, default: 0
    add_column :monuments, :featured_count, :integer, default: 0
  end
end
