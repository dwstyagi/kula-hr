class CreateBackgroundTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :background_tasks do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :task_key, null: false
      t.string :status, null: false, default: "queued"
      t.jsonb :payload, null: false, default: {}
      t.jsonb :result, null: false, default: {}
      t.timestamps
    end
    add_index :background_tasks, [ :tenant_id, :kind, :task_key ], unique: true,
      where: "status IN ('queued', 'running')", name: "idx_background_tasks_active"
  end
end
