class CreateProfessionalTaxSlabs < ActiveRecord::Migration[8.1]
  def change
    create_table :professional_tax_slabs do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :state, null: false
      t.decimal :salary_from, precision: 10, scale: 2, null: false
      t.decimal :salary_to, precision: 10, scale: 2, null: false
      t.decimal :tax_amount, precision: 10, scale: 2, null: false
      t.string :month # nil means all months, "february" for special Feb slab

      t.timestamps
    end
  end
end
