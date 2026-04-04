class AddPerformanceIndexes < ActiveRecord::Migration[8.1]
  def change
    add_index :payroll_runs,           [ :tenant_id, :status ],        name: "idx_payroll_runs_tenant_status"
    add_index :payslips,               [ :payroll_run_id, :status ],   name: "idx_payslips_run_status"
    add_index :attendance_summaries,   [ :tenant_id, :status ],        name: "idx_att_sum_tenant_status"
    add_index :professional_tax_slabs, [ :tenant_id, :state, :month ], name: "idx_pt_slabs_tenant_state_month"
    add_index :tax_declarations,       [ :employee_id, :status ],      name: "idx_tax_decl_emp_status"
  end
end
