class CreateEmployees < ActiveRecord::Migration[8.0]
  def change
    create_table :employees do |t|
      # Tenant + User link
      t.references :tenant, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :department, foreign_key: true
      t.references :designation, foreign_key: true
      t.references :reporting_manager, foreign_key: { to_table: :employees }

      # Identity
      t.string :employee_code, null: false
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email, null: false
      t.string :phone
      t.date :date_of_birth
      t.string :gender

      # Employment
      t.date :joining_date, null: false
      t.date :confirmation_date
      t.date :resignation_date
      t.date :last_working_date
      t.string :employment_status, null: false, default: "active"

      # Bank details
      t.string :bank_name
      t.string :bank_account_number
      t.string :ifsc_code

      # Statutory
      t.string :pan_number
      t.string :aadhaar_number
      t.string :uan_number
      t.string :esi_number

      # Address
      t.text :current_address
      t.string :city
      t.string :state
      t.string :pincode

      # Emergency contact
      t.string :emergency_contact_name
      t.string :emergency_contact_phone
      t.string :emergency_contact_relation

      t.timestamps
    end

    add_index :employees, [ :tenant_id, :employee_code ], unique: true
    add_index :employees, [ :tenant_id, :email ], unique: true
    add_index :employees, :employment_status
  end
end
