class CreateAttendanceSummaries < ActiveRecord::Migration[8.0]
  def change
    create_table :attendance_summaries do |t|
      t.references :tenant,   null: false, foreign_key: true
      t.references :employee, null: false, foreign_key: true
      t.integer :month,  null: false
      t.integer :year,   null: false
      t.integer :status, null: false, default: 0  # 0=draft, 1=locked

      # Working day counts — all stored as decimals to support half-days
      t.decimal :total_working_days,  precision: 5, scale: 1, null: false, default: 0
      t.decimal :days_present,        precision: 5, scale: 1, null: false, default: 0
      t.decimal :approved_leaves,     precision: 5, scale: 1, null: false, default: 0  # paid leave days (auto)
      t.decimal :lop_leaves,          precision: 5, scale: 1, null: false, default: 0  # approved LOP leave days (auto)
      t.decimal :half_days,           precision: 5, scale: 1, null: false, default: 0  # half-day count (HR edits)
      t.decimal :unapproved_absences, precision: 5, scale: 1, null: false, default: 0  # calculated
      t.decimal :lop_days,            precision: 5, scale: 1, null: false, default: 0  # calculated
      t.decimal :paid_days,           precision: 5, scale: 1, null: false, default: 0  # calculated

      t.timestamps
    end

    add_index :attendance_summaries, [ :employee_id, :month, :year ],
              unique: true, name: "idx_att_sum_emp_month_year"
    add_index :attendance_summaries, [ :tenant_id, :month, :year ],
              name: "idx_att_sum_tenant_month_year"
  end
end
