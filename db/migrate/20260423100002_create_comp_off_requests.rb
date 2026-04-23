class CreateCompOffRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :comp_off_requests do |t|
      t.references :tenant,      null: false, foreign_key: true
      t.references :employee,    null: false, foreign_key: true
      t.references :approved_by, foreign_key: { to_table: :users }, null: true

      t.date     :worked_date,     null: false
      t.string   :reason
      t.integer  :status,          null: false, default: 0
      t.string   :rejection_reason
      t.datetime :approved_at
      t.date     :expiry_date
      t.boolean  :balance_expired, null: false, default: false

      t.timestamps
    end

    add_index :comp_off_requests,
              [ :employee_id, :worked_date ],
              name: "idx_comp_off_emp_worked_date"
  end
end
