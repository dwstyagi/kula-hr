class AddPayslipToLeaveEncashmentRequests < ActiveRecord::Migration[8.1]
  def change
    add_reference :leave_encashment_requests, :payslip, null: true, foreign_key: true
  end
end
