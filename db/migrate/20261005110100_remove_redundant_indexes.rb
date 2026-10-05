# Each of these is the leading column of a composite index on the same table,
# which already serves the same lookups. Dropping them saves a write per row.
class RemoveRedundantIndexes < ActiveRecord::Migration[8.1]
  def change
    remove_index :payslips, :employee_id, name: "index_payslips_on_employee_id"             # (employee_id, month, year)
    remove_index :payslips, :payroll_run_id, name: "index_payslips_on_payroll_run_id"       # (payroll_run_id, employee_id) unique
    remove_index :attendance_summaries, :employee_id, name: "index_attendance_summaries_on_employee_id" # (employee_id, month, year) unique
  end
end
