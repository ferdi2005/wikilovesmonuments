class AddNowlmToNophotos < ActiveRecord::Migration[5.2]
  def change
    add_column :nophotos, :nowlm, :integer
  end
end
