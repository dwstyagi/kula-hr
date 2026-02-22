class CreateLeaveRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :leave_requests do |t|
      t.references :tenant,     null: false, foreign_key: true
      t.references :employee,   null: false, foreign_key: true
      t.references :leave_type, null: false, foreign_key: true
      t.date    :from_date,       null: false
      t.date    :to_date,         null: false
      t.decimal :number_of_days,  precision: 5, scale: 1, null: false
      t.text    :reason
      t.integer :status,          null: false, default: 0
      t.references :approved_by, foreign_key: { to_table: :users }, null: true
      t.datetime :approved_at
      t.text :rejection_reason

      t.timestamps
    end

    add_index :leave_requests, [ :tenant_id, :status ]
    add_index :leave_requests, [ :employee_id, :from_date, :to_date ]
  end
end
