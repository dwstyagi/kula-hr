class CreateEmployeeSalaries < ActiveRecord::Migration[8.1]
  def change
    create_table :employee_salaries do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :employee, null: false, foreign_key: true
      t.references :salary_structure, null: false, foreign_key: true
      t.decimal :annual_ctc, precision: 12, scale: 2, null: false
      t.date :effective_from, null: false
      t.date :effective_to

      t.timestamps
    end

    add_index :employee_salaries, [ :employee_id, :effective_from ]
    add_index :employee_salaries, [ :employee_id, :effective_to ]
  end
end
