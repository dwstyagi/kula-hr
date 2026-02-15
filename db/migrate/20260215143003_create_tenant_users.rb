class CreateTenantUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :tenant_users do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :tenant_users, [:tenant_id, :user_id], unique: true
  end
end
