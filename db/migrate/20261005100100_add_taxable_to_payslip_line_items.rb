# Whether an earning counts toward taxable income. TDS projection sums taxable
# earnings already paid this financial year, so the flag has to be stored on
# the payslip at the time it was paid, not looked up from today's component.
class AddTaxableToPayslipLineItems < ActiveRecord::Migration[8.1]
  def change
    add_column :payslip_line_items, :taxable, :boolean, default: true, null: false
  end
end
