class AddEmployerPfInCtc < ActiveRecord::Migration[8.1]
  def change
    # Tenant-wide toggle: when true, the employer PF + admin + EDLI are carved out
    # of the employee's CTC (borne by the employee) instead of paid on top.
    add_column :payroll_settings, :employer_pf_in_ctc, :boolean, default: false, null: false

    # Persist the employer-side PF charges on each payslip so the CTC reconciles
    # and the payslip can itemise them.
    add_column :payslips, :employer_pf_admin, :decimal, precision: 10, scale: 2, default: 0, null: false
    add_column :payslips, :employer_edli,     :decimal, precision: 10, scale: 2, default: 0, null: false
  end
end
