class CreateSalaryComponents < ActiveRecord::Migration[8.1]
  def change
    create_table :salary_components do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :name, null: false
      t.string :component_type, null: false  # earning, deduction, employer_contribution
      t.string :calculation_type, null: false # flat, percentage
      t.boolean :taxable, default: true
      t.boolean :active, default: true
      t.integer :sort_order, default: 0

      t.timestamps
    end

    add_index :salary_components, [ :tenant_id, :name ], unique: true
  end
end
