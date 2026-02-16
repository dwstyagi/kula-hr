class CreateDesignations < ActiveRecord::Migration[8.1]
  def change
    create_table :designations do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end

    add_index :designations, [ :tenant_id, :name ], unique: true
  end
end
