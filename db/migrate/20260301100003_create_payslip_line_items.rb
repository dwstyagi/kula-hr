class CreatePayslipLineItems < ActiveRecord::Migration[8.1]
  def change
    create_table :payslip_line_items do |t|
      t.references :payslip, null: false, foreign_key: true

      t.string  :component_name, null: false   # "Basic", "HRA", "PF", "TDS"
      t.string  :component_type, null: false   # "earning" or "deduction"
      t.decimal :amount,      precision: 12, scale: 2, null: false
      t.decimal :full_amount, precision: 12, scale: 2  # before LOP proration
      t.integer :sort_order,  default: 0
      t.string  :category                      # "fixed", "variable", "statutory"

      t.timestamps
    end

    add_index :payslip_line_items, [ :payslip_id, :component_type ]
  end
end
