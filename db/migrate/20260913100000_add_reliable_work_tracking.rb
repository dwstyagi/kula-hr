class AddReliableWorkTracking < ActiveRecord::Migration[8.1]
  def change
    create_table :job_dispatches do |t|
      t.string :job_class, null: false
      t.jsonb :arguments, null: false, default: []
      t.datetime :dispatched_at
      t.integer :attempts, null: false, default: 0
      t.text :last_error
      t.timestamps
      t.index :dispatched_at
    end
    create_table :leave_accruals do |t|
      t.references :tenant, null: false, foreign_key: true
      t.date :period, null: false
      t.timestamps
      t.index [ :tenant_id, :period ], unique: true
    end
    add_column :tenants, :employee_sequence, :bigint, null: false, default: 0
  end
end
