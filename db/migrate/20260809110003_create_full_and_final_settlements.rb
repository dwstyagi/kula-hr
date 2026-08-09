class CreateFullAndFinalSettlements < ActiveRecord::Migration[8.1]
  def change
    create_table :full_and_final_settlements do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :payroll_run, null: false, foreign_key: true,
                                 index: { unique: true, name: "idx_faf_settlements_unique_run" }
      t.references :employee, null: false, foreign_key: true
      t.references :payslip, null: true, foreign_key: true

      t.date :last_working_date, null: false
      t.decimal :salary_days, precision: 6, scale: 2, null: false, default: 0
      t.decimal :leave_encashment_days, precision: 6, scale: 2, null: false, default: 0

      t.decimal :earned_salary, precision: 12, scale: 2, null: false, default: 0
      t.decimal :leave_encashment, precision: 12, scale: 2, null: false, default: 0
      t.decimal :bonus, precision: 12, scale: 2, null: false, default: 0
      t.decimal :notice_pay, precision: 12, scale: 2, null: false, default: 0
      t.decimal :gratuity, precision: 12, scale: 2, null: false, default: 0
      t.decimal :other_earnings, precision: 12, scale: 2, null: false, default: 0

      t.decimal :notice_recovery, precision: 12, scale: 2, null: false, default: 0
      t.decimal :loan_recovery, precision: 12, scale: 2, null: false, default: 0
      t.decimal :asset_recovery, precision: 12, scale: 2, null: false, default: 0
      t.decimal :other_deductions, precision: 12, scale: 2, null: false, default: 0
      t.decimal :pf_amount, precision: 12, scale: 2, null: false, default: 0
      t.decimal :esi_amount, precision: 12, scale: 2, null: false, default: 0
      t.decimal :professional_tax_amount, precision: 12, scale: 2, null: false, default: 0
      t.decimal :tds_amount, precision: 12, scale: 2, null: false, default: 0

      t.text :notes
      t.timestamps
    end

    add_index :full_and_final_settlements, [ :tenant_id, :employee_id ],
              name: "idx_faf_settlements_tenant_employee"
  end
end
