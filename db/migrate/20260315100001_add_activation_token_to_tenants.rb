class AddActivationTokenToTenants < ActiveRecord::Migration[8.1]
  def change
    add_column :tenants, :activation_token, :string
    add_column :tenants, :activation_token_expires_at, :datetime
    add_index :tenants, :activation_token, unique: true
  end
end
