class CreatePayslips < ActiveRecord::Migration[8.1]
  def change
    create_table :payslips do |t|
      t.references :tenant,      null: false, foreign_key: true
      t.references :payroll_run, null: false, foreign_key: true
      t.references :employee,    null: false, foreign_key: true

      t.integer :month, null: false
      t.integer :year,  null: false

      # Headline amounts
      t.decimal :gross_pay,        precision: 12, scale: 2, null: false, default: 0
      t.decimal :total_deductions, precision: 12, scale: 2, null: false, default: 0
      t.decimal :net_pay,          precision: 12, scale: 2, null: false, default: 0

      # Employer costs (not deducted from employee — company bears these)
      t.decimal :employer_pf,  precision: 10, scale: 2, default: 0
      t.decimal :employer_esi, precision: 10, scale: 2, default: 0

      # Attendance context (snapshot at time of payroll)
      t.integer :total_working_days, null: false
      t.decimal :paid_days,          precision: 5, scale: 1, null: false
      t.decimal :lop_days,           precision: 5, scale: 1, default: 0

      # Status
      t.string  :status,         null: false, default: "generated"
      t.boolean :is_revised,     default: false
      t.text    :revision_notes

      t.timestamps
    end

    # One payslip per employee per payroll run
    add_index :payslips, [ :payroll_run_id, :employee_id ], unique: true
    # Fast lookup: employee's payslip history
    add_index :payslips, [ :employee_id, :month, :year ]
  end
end
