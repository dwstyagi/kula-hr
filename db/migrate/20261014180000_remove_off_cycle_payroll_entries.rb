class RemoveOffCyclePayrollEntries < ActiveRecord::Migration[8.1]
  def change
    # Run headers, generated payslips and line items remain as financial history.
    # Only the input table belonging to the retired feature is removed.
    drop_table :off_cycle_payroll_entries do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :payroll_run, null: false, foreign_key: true
      t.references :employee, null: false, foreign_key: true
      t.decimal :gross_amount, precision: 12, scale: 2, null: false
      t.decimal :tds_amount, precision: 12, scale: 2, null: false, default: 0
      t.text :notes
      t.timestamps
      t.index [ :payroll_run_id, :employee_id ], unique: true, name: "idx_off_cycle_entries_run_employee"
    end
  end
end
