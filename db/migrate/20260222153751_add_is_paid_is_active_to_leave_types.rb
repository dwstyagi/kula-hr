class AddIsPaidIsActiveToLeaveTypes < ActiveRecord::Migration[8.1]
  def change
    add_column :leave_types, :is_paid, :boolean, default: true, null: false
    add_column :leave_types, :is_active, :boolean, default: true, null: false
  end
end
