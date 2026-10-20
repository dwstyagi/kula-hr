class CompleteLeaveWorkflows < ActiveRecord::Migration[8.1]
  def up
    %i[total_days used_days remaining_days carried_forward_days encashed_days].each do |column|
      change_column :leave_balances, column, :decimal, precision: 12, scale: 4, default: 0, null: false
    end
    add_column :leave_requests, :duration, :string, default: "full_day", null: false
    add_column :leave_requests, :regularization_note, :text
    add_column :leave_requests, :cancellation_requested_at, :datetime
    add_column :leave_requests, :cancellation_reason, :text
    add_column :attendance_summaries, :leave_adjusted_present_days, :decimal, precision: 8, scale: 4, default: 0, null: false
    create_table :leave_request_events do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :leave_request, null: false, foreign_key: true
      t.references :actor, foreign_key: { to_table: :users }
      t.string :action, null: false
      t.text :reason
      t.timestamps
    end
    create_table :leave_balance_entries do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :leave_balance, null: false, foreign_key: true
      t.references :actor, foreign_key: { to_table: :users }
      t.string :kind, null: false
      t.string :reference
      t.text :reason
      %i[total_days used_days remaining_days carried_forward_days encashed_days].each do |column|
        t.decimal column, precision: 12, scale: 4, null: false
        t.decimal "change_#{column}", precision: 12, scale: 4, null: false
      end
      t.timestamps
    end
    add_index :leave_balance_entries, [ :leave_balance_id, :reference ], unique: true, name: "idx_leave_entry_reference"
    execute <<~SQL
      INSERT INTO leave_balance_entries
        (tenant_id, leave_balance_id, kind, reason, total_days, used_days, remaining_days,
         carried_forward_days, encashed_days, change_total_days, change_used_days,
         change_remaining_days, change_carried_forward_days, change_encashed_days, created_at, updated_at)
      SELECT tenant_id, id, 'opening', 'Balance at audit-history introduction; earlier transactions are not reconstructed',
        total_days, used_days, remaining_days, carried_forward_days, encashed_days,
        total_days, used_days, remaining_days, carried_forward_days, encashed_days, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM leave_balances
    SQL
    add_index :leave_requests, [ :tenant_id, :cancellation_requested_at ], name: 'idx_leave_cancellation_queue'
  end

  def down
    drop_table :leave_balance_entries
    drop_table :leave_request_events
    remove_column :attendance_summaries, :leave_adjusted_present_days
    remove_index :leave_requests, name: 'idx_leave_cancellation_queue'
    %i[duration regularization_note cancellation_requested_at cancellation_reason].each { |column| remove_column :leave_requests, column }
    # Keep increased balance precision on rollback to avoid losing earned fractions.
  end
end
