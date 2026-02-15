class CreateTenants < ActiveRecord::Migration[8.1]
  def change
    create_table :tenants do |t|
      t.string :name, null: false
      t.citext :subdomain, null: false
      t.string :address
      t.string :city
      t.string :state
      t.string :pincode
      t.string :gstin
      t.string :pan
      t.string :tan
      t.string :pf_establishment_code
      t.string :esi_code
      t.string :status, null: false, default: "trial"

      t.timestamps
    end

    add_index :tenants, :subdomain, unique: true
    add_index :tenants, :status
  end
end
