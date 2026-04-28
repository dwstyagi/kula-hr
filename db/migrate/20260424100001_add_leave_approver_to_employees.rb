class AddLeaveApproverToEmployees < ActiveRecord::Migration[8.1]
  def change
    add_column :employees, :leave_approver, :integer, default: 0, null: false
  end
end
