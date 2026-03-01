class CreatePayrollRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :payroll_runs do |t|
      t.references :tenant,       null: false, foreign_key: true
      t.integer    :month,        null: false
      t.integer    :year,         null: false
      t.string     :status,       null: false, default: "draft"

      # Progress counters
      t.integer    :total_employees,     default: 0
      t.integer    :processed_employees, default: 0

      # Aggregate totals (filled after processing)
      t.decimal :total_gross,        precision: 12, scale: 2, default: 0
      t.decimal :total_deductions,   precision: 12, scale: 2, default: 0
      t.decimal :total_net_pay,      precision: 12, scale: 2, default: 0
      t.decimal :total_employer_cost, precision: 12, scale: 2, default: 0

      # Who did what
      t.references :initiated_by, foreign_key: { to_table: :users }, null: false
      t.references :approved_by,  foreign_key: { to_table: :users }, null: true

      t.datetime :approved_at
      t.text     :rejection_reason
      t.text     :notes

      t.timestamps
    end

    add_index :payroll_runs, [ :tenant_id, :month, :year ],
              unique: true,
              name: "idx_payroll_run_tenant_month_year"
  end
end
