class AddAccountActiveToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :account_active, :boolean, default: true, null: false
  end
end
