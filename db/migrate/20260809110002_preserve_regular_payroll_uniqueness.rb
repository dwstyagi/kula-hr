class PreserveRegularPayrollUniqueness < ActiveRecord::Migration[8.1]
  def up
    add_column :payroll_runs, :regular_period_sequence, :integer, null: false, default: 0

    # Some older installations contain duplicate periods because their live
    # index drifted from the tracked unique schema. Preserve that history by
    # giving only legacy duplicates a non-zero sequence. New records always use
    # zero, so the unique partial index still prevents future duplicate runs.
    execute <<~SQL.squish
      WITH ranked AS (
        SELECT id,
               ROW_NUMBER() OVER (
                 PARTITION BY tenant_id, month, year
                 ORDER BY created_at, id
               ) - 1 AS sequence
        FROM payroll_runs
        WHERE run_type = 'regular'
      )
      UPDATE payroll_runs
      SET regular_period_sequence = ranked.sequence
      FROM ranked
      WHERE payroll_runs.id = ranked.id
    SQL

    remove_index :payroll_runs, name: "idx_regular_payroll_run_tenant_period"
    add_index :payroll_runs,
              [ :tenant_id, :month, :year, :regular_period_sequence ],
              unique: true,
              where: "run_type = 'regular'",
              name: "idx_unique_regular_payroll_period"
  end

  def down
    remove_index :payroll_runs, name: "idx_unique_regular_payroll_period"
    remove_column :payroll_runs, :regular_period_sequence
    add_index :payroll_runs, [ :tenant_id, :month, :year ],
              where: "run_type = 'regular'",
              name: "idx_regular_payroll_run_tenant_period"
  end
end
