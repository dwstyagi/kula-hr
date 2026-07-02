class CreateAnnouncements < ActiveRecord::Migration[8.1]
  def change
    create_table :announcements do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.text :body
      t.boolean :published, null: false, default: false
      t.datetime :published_at

      t.timestamps
    end

    add_index :announcements, [ :tenant_id, :published, :published_at ]

    create_table :announcement_reads do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :announcement, null: false, foreign_key: true
      t.references :employee, null: false, foreign_key: true
      t.datetime :read_at, null: false

      t.timestamps
    end

    add_index :announcement_reads, [ :announcement_id, :employee_id ], unique: true
  end
end
