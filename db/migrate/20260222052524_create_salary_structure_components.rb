class CreateSalaryStructureComponents < ActiveRecord::Migration[8.1]
  def change
    create_table :salary_structure_components do |t|
      t.references :salary_structure, null: false, foreign_key: true
      t.references :salary_component, null: false, foreign_key: true
      t.decimal :value, precision: 10, scale: 2, null: false

      t.timestamps
    end

    add_index :salary_structure_components, [ :salary_structure_id, :salary_component_id ], unique: true, name: "idx_structure_components_unique"
  end
end
