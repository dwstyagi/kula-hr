class AddOffCyclePayroll < ActiveRecord::Migration[8.1]
  def up
    add_column :payroll_runs, :run_type, :string, null: false, default: "regular"
    add_column :payroll_runs, :title, :string
    add_column :payroll_runs, :payment_date, :date

    # One regular run per tenant per period, same guarantee as before. The index
    # becomes partial so off-cycle runs, which are deliberately unconstrained in
    # number, can share a period with the regular run and with each other.
    remove_index :payroll_runs, name: "idx_payroll_run_tenant_month_year"
    add_index :payroll_runs, [ :tenant_id, :month, :year ],
              unique: true,
              where: "run_type = 'regular'",
              name: "idx_regular_payroll_run_tenant_period"
    add_index :payroll_runs, [ :tenant_id, :run_type, :payment_date ],
              name: "idx_payroll_runs_tenant_type_payment"

    create_table :off_cycle_payroll_entries do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :payroll_run, null: false, foreign_key: true
      t.references :employee, null: false, foreign_key: true
      t.decimal :gross_amount, precision: 12, scale: 2, null: false
      t.decimal :tds_amount, precision: 12, scale: 2, null: false, default: 0
      t.text :notes

      t.timestamps
    end

    add_index :off_cycle_payroll_entries, [ :payroll_run_id, :employee_id ],
              unique: true,
              name: "idx_off_cycle_entries_run_employee"
  end

  def down
    drop_table :off_cycle_payroll_entries

    remove_index :payroll_runs, name: "idx_payroll_runs_tenant_type_payment"
    remove_index :payroll_runs, name: "idx_regular_payroll_run_tenant_period"
    remove_column :payroll_runs, :payment_date
    remove_column :payroll_runs, :title
    remove_column :payroll_runs, :run_type

    add_index :payroll_runs, [ :tenant_id, :month, :year ],
              unique: true,
              name: "idx_payroll_run_tenant_month_year"
  end
end
