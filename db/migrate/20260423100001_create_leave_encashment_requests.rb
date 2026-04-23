class CreateLeaveEncashmentRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :leave_encashment_requests do |t|
      t.references :tenant,    null: false, foreign_key: true
      t.references :employee,  null: false, foreign_key: true
      t.references :leave_type, null: false, foreign_key: true
      t.references :approved_by, foreign_key: { to_table: :users }, null: true

      t.string  :financial_year,     null: false
      t.decimal :number_of_days,     precision: 5,  scale: 1, null: false
      t.decimal :encashment_amount,  precision: 12, scale: 2
      t.integer :status,             null: false, default: 0
      t.string  :rejection_reason
      t.datetime :approved_at

      t.timestamps
    end

    add_index :leave_encashment_requests,
              [ :employee_id, :leave_type_id, :financial_year ],
              unique: true,
              name: "idx_encashment_emp_leavetype_fy"
  end
end
