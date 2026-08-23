class AllowMultipleFullAndFinalSettlements < ActiveRecord::Migration[8.1]
  def up
    # A settlement run now covers a batch of exits rather than a single one.
    # Uniqueness moves from the run to the pair, so one run can hold many
    # settlements while still refusing the same employee twice.
    remove_index :full_and_final_settlements, name: "idx_faf_settlements_unique_run"
    add_index :full_and_final_settlements, :payroll_run_id,
              name: "idx_faf_settlements_run"
    add_index :full_and_final_settlements, [ :payroll_run_id, :employee_id ],
              unique: true,
              name: "idx_faf_settlements_run_employee"
  end

  def down
    remove_index :full_and_final_settlements, name: "idx_faf_settlements_run_employee"
    remove_index :full_and_final_settlements, name: "idx_faf_settlements_run"
    add_index :full_and_final_settlements, :payroll_run_id,
              unique: true,
              name: "idx_faf_settlements_unique_run"
  end
end
