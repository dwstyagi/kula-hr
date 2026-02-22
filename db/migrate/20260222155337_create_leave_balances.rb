class CreateLeaveBalances < ActiveRecord::Migration[8.1]
  def change
    create_table :leave_balances do |t|
      t.references :tenant,     null: false, foreign_key: true
      t.references :employee,   null: false, foreign_key: true
      t.references :leave_type, null: false, foreign_key: true
      t.decimal :total_days,           precision: 5, scale: 1, null: false, default: 0
      t.decimal :used_days,            precision: 5, scale: 1, null: false, default: 0
      t.decimal :remaining_days,       precision: 5, scale: 1, null: false, default: 0
      t.decimal :carried_forward_days, precision: 5, scale: 1, null: false, default: 0
      t.string  :financial_year, null: false

      t.timestamps
    end

    add_index :leave_balances, [ :employee_id, :leave_type_id, :financial_year ],
              unique: true, name: "idx_leave_bal_emp_type_fy"
  end
end
