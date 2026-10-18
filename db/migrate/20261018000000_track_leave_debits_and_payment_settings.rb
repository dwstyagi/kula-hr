class TrackLeaveDebitsAndPaymentSettings < ActiveRecord::Migration[8.1]
  def up
    add_column :payroll_settings, :hdfc_corporate_code, :string
    add_column :payroll_settings, :salary_debit_account, :string
    add_column :leave_balances, :encashed_days, :decimal, precision: 8, scale: 2, null: false, default: 0
    add_column :leave_encashment_requests, :balance_reserved, :boolean, null: false, default: false
    add_column :comp_off_requests, :remaining_days, :decimal, precision: 5, scale: 2, null: false, default: 1

    create_table :leave_balance_debits do |t|
      t.references :leave_request, null: false, foreign_key: true
      t.references :leave_balance, null: false, foreign_key: true
      t.decimal :number_of_days, precision: 8, scale: 2, null: false
      t.datetime :reversed_at
      t.timestamps
      t.index [ :leave_request_id, :leave_balance_id ], unique: true, name: "idx_leave_debits_request_balance"
    end
    create_table :comp_off_usages do |t|
      t.references :comp_off_request, null: false, foreign_key: true
      t.references :leave_request, null: false, foreign_key: true
      t.decimal :number_of_days, precision: 5, scale: 2, null: false
      t.timestamps
      t.index [ :comp_off_request_id, :leave_request_id ], unique: true, name: "idx_comp_off_usage_credit_leave"
    end

    reconcile_comp_off_credits
  end

  # Reconstruct legacy remainders with FIFO consumption, preserving the recorded
  # aggregate balance. Pending requests keep their full future credit.
  def reconcile_comp_off_credits
    execute "UPDATE comp_off_requests SET remaining_days = 0 WHERE status = 1"
    execute <<~SQL
      WITH credits AS (
        SELECT c.id,
          GREATEST(LEAST(1, b.remaining_days - ROW_NUMBER() OVER (
            PARTITION BY b.id ORDER BY c.expiry_date DESC, c.id DESC) + 1), 0) AS remainder
        FROM comp_off_requests c
        JOIN leave_types lt ON lt.tenant_id = c.tenant_id AND lt.code = 'CO'
        JOIN leave_balances b ON b.employee_id = c.employee_id AND b.leave_type_id = lt.id
          AND b.financial_year = CONCAT(
            EXTRACT(YEAR FROM COALESCE(c.approved_at, c.created_at) - INTERVAL '3 months')::integer, '-',
            RIGHT((EXTRACT(YEAR FROM COALESCE(c.approved_at, c.created_at) - INTERVAL '3 months')::integer + 1)::text, 2))
        WHERE c.status = 1 AND c.balance_expired = FALSE
      )
      UPDATE comp_off_requests c SET remaining_days = credits.remainder
      FROM credits WHERE credits.id = c.id
    SQL
  end

  def down
    drop_table :comp_off_usages
    drop_table :leave_balance_debits
    remove_column :comp_off_requests, :remaining_days
    remove_column :leave_encashment_requests, :balance_reserved
    remove_column :leave_balances, :encashed_days
    remove_column :payroll_settings, :salary_debit_account
    remove_column :payroll_settings, :hdfc_corporate_code
  end
end
