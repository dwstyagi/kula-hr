class CreateSalaryStructures < ActiveRecord::Migration[8.1]
  def change
    create_table :salary_structures do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :name, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :salary_structures, [ :tenant_id, :name ], unique: true
  end
end
