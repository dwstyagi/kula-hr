class CreateInvestmentDeclarations < ActiveRecord::Migration[8.1]
  def change
    create_table :investment_declarations do |t|
      t.references :tenant,          null: false, foreign_key: true
      t.references :tax_declaration,  null: false, foreign_key: true

      t.string  :section,         null: false  # "80C", "80D", "80CCD1B", "80E", "80G", "80TTA", "24b"
      t.string  :description,     null: false  # "PPF", "LIC Premium", "Health Insurance (Self)", etc.
      t.decimal :declared_amount, precision: 10, scale: 2, null: false
      t.decimal :verified_amount, precision: 10, scale: 2  # HR verifies with proof (used in v2)

      t.timestamps
    end

    add_index :investment_declarations, [ :tax_declaration_id, :section ],
              name: "idx_inv_decl_td_section"
  end
end
