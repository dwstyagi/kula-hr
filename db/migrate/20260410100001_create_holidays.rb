class CreateHolidays < ActiveRecord::Migration[8.1]
  def change
    create_table :holidays do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string  :name,      null: false
      t.date    :date,      null: false
      t.boolean :is_active, null: false, default: true

      t.timestamps
    end

    add_index :holidays, [ :tenant_id, :date ], unique: true
  end
end
