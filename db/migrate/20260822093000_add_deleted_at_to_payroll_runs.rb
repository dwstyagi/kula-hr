class AddDeletedAtToPayrollRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :payroll_runs, :deleted_at, :datetime
    # Partial: only soft-deleted rows are ever looked up by this, and they are
    # the rare case. Keeps the index off the hot path for live runs.
    add_index :payroll_runs, [ :tenant_id, :deleted_at ],
              where: "deleted_at IS NOT NULL",
              name: "idx_payroll_runs_tenant_deleted"
  end
end
