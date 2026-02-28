class CreateTaxDeclarations < ActiveRecord::Migration[8.1]
  def change
    create_table :tax_declarations do |t|
      t.references :tenant,   null: false, foreign_key: true
      t.references :employee, null: false, foreign_key: true

      t.string  :financial_year, null: false          # e.g. "2025-26"
      t.integer :regime,         null: false, default: 1  # 0 = old, 1 = new
      t.integer :status,         null: false, default: 0  # 0 = draft, 1 = submitted, 2 = verified

      # HRA Exemption (Old Regime only)
      t.boolean :claiming_hra,   default: false, null: false
      t.decimal :monthly_rent,   precision: 10, scale: 2, default: 0
      t.string  :landlord_name
      t.string  :landlord_pan    # Required if annual rent > ₹1,00,000
      t.string  :rental_city     # "metro" or "non_metro" — affects HRA % cap

      # Home Loan (Old Regime only)
      t.decimal :home_loan_interest,  precision: 10, scale: 2, default: 0  # Section 24(b), max ₹2L
      t.decimal :home_loan_principal, precision: 10, scale: 2, default: 0  # Counts under 80C

      # Computed totals — recalculated whenever investments change
      t.decimal :total_declared_investments, precision: 12, scale: 2, default: 0
      t.decimal :total_exempt_allowances,    precision: 12, scale: 2, default: 0
      t.decimal :estimated_annual_tax,       precision: 12, scale: 2, default: 0
      t.decimal :estimated_monthly_tds,      precision: 10, scale: 2, default: 0

      t.timestamps
    end

    add_index :tax_declarations, [:employee_id, :financial_year],
              unique: true, name: "idx_tax_decl_emp_fy"
  end
end
