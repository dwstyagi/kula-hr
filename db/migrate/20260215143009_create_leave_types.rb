class CreateLeaveTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :leave_types do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :name, null: false
      t.string :code, null: false
      t.decimal :annual_quota, precision: 5, scale: 1, default: 0
      t.boolean :carry_forward, default: false
      t.decimal :max_carry_forward, precision: 5, scale: 1, default: 0

      t.timestamps
    end

    add_index :leave_types, [:tenant_id, :code], unique: true
  end
end
