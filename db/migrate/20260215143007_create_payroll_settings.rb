class CreatePayrollSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :payroll_settings do |t|
      t.references :tenant, null: false, foreign_key: true, index: { unique: true }
      t.decimal :pf_employee_rate, precision: 5, scale: 2, default: 12.0
      t.decimal :pf_employer_rate, precision: 5, scale: 2, default: 12.0
      t.decimal :pf_ceiling, precision: 10, scale: 2, default: 15000.0
      t.decimal :esi_employee_rate, precision: 5, scale: 2, default: 0.75
      t.decimal :esi_employer_rate, precision: 5, scale: 2, default: 3.25
      t.decimal :esi_ceiling, precision: 10, scale: 2, default: 21000.0
      t.string :state

      t.timestamps
    end
  end
end
