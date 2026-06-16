class CreateWorkLocations < ActiveRecord::Migration[8.1]
  def change
    create_table :work_locations do |t|
      t.string :name, null: false
      t.string :state
      t.boolean :is_active, default: true, null: false
      t.references :tenant, null: false, foreign_key: true

      t.timestamps
    end

    add_index :work_locations, [ :tenant_id, :name ], unique: true

    # A nil work_location_id means the holiday is company-wide (all locations).
    add_reference :holidays, :work_location, foreign_key: true, null: true
    # A nil work_location_id means the employee follows company-wide holidays only.
    add_reference :employees, :work_location, foreign_key: true, null: true

    # The existing unique index on [tenant_id, date] is too strict once holidays
    # can be location-specific: two locations may share a date. Replace it with a
    # uniqueness scoped by location as well.
    remove_index :holidays, column: [ :tenant_id, :date ], name: "index_holidays_on_tenant_id_and_date"
    add_index :holidays, [ :tenant_id, :work_location_id, :date ],
              unique: true, name: "index_holidays_on_tenant_location_date"
  end
end
