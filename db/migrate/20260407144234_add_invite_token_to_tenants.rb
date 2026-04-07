class AddInviteTokenToTenants < ActiveRecord::Migration[8.1]
  def change
    add_column :tenants, :invite_token, :string
    add_column :tenants, :invite_token_expires_at, :datetime
    add_index :tenants, :invite_token, unique: true
  end
end
