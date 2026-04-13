# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_04_10_100001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "attendance_summaries", force: :cascade do |t|
    t.decimal "approved_leaves", precision: 5, scale: 1, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.decimal "days_present", precision: 5, scale: 1, default: "0.0", null: false
    t.bigint "employee_id", null: false
    t.decimal "half_days", precision: 5, scale: 1, default: "0.0", null: false
    t.decimal "lop_days", precision: 5, scale: 1, default: "0.0", null: false
    t.decimal "lop_leaves", precision: 5, scale: 1, default: "0.0", null: false
    t.integer "month", null: false
    t.decimal "paid_days", precision: 5, scale: 1, default: "0.0", null: false
    t.integer "status", default: 0, null: false
    t.bigint "tenant_id", null: false
    t.decimal "total_working_days", precision: 5, scale: 1, default: "0.0", null: false
    t.decimal "unapproved_absences", precision: 5, scale: 1, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.integer "year", null: false
    t.index ["employee_id", "month", "year"], name: "idx_att_sum_emp_month_year", unique: true
    t.index ["employee_id"], name: "index_attendance_summaries_on_employee_id"
    t.index ["tenant_id", "month", "year"], name: "idx_att_sum_tenant_month_year"
    t.index ["tenant_id", "status"], name: "idx_att_sum_tenant_status"
    t.index ["tenant_id"], name: "index_attendance_summaries_on_tenant_id"
  end

  create_table "departments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "name"], name: "index_departments_on_tenant_id_and_name", unique: true
    t.index ["tenant_id"], name: "index_departments_on_tenant_id"
  end

  create_table "designations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "name"], name: "index_designations_on_tenant_id_and_name", unique: true
    t.index ["tenant_id"], name: "index_designations_on_tenant_id"
  end

  create_table "employee_salaries", force: :cascade do |t|
    t.decimal "annual_ctc", precision: 12, scale: 2, null: false
    t.datetime "created_at", null: false
    t.date "effective_from", null: false
    t.date "effective_to"
    t.bigint "employee_id", null: false
    t.bigint "salary_structure_id", null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id", "effective_from"], name: "index_employee_salaries_on_employee_id_and_effective_from"
    t.index ["employee_id", "effective_to"], name: "index_employee_salaries_on_employee_id_and_effective_to"
    t.index ["employee_id"], name: "index_employee_salaries_on_employee_id"
    t.index ["salary_structure_id"], name: "index_employee_salaries_on_salary_structure_id"
    t.index ["tenant_id"], name: "index_employee_salaries_on_tenant_id"
  end

  create_table "employees", force: :cascade do |t|
    t.string "aadhaar_number"
    t.string "bank_account_number"
    t.string "bank_name"
    t.string "city"
    t.date "confirmation_date"
    t.datetime "created_at", null: false
    t.text "current_address"
    t.date "date_of_birth"
    t.bigint "department_id"
    t.bigint "designation_id"
    t.string "email", null: false
    t.string "emergency_contact_name"
    t.string "emergency_contact_phone"
    t.string "emergency_contact_relation"
    t.string "employee_code", null: false
    t.string "employment_status", default: "active", null: false
    t.string "esi_number"
    t.string "first_name", null: false
    t.string "gender"
    t.string "ifsc_code"
    t.date "joining_date", null: false
    t.string "last_name", null: false
    t.date "last_working_date"
    t.string "pan_number"
    t.boolean "pf_applicable", default: true, null: false
    t.boolean "pf_on_full_basic", default: false, null: false
    t.string "phone"
    t.string "pincode"
    t.boolean "pt_applicable", default: true, null: false
    t.bigint "reporting_manager_id"
    t.date "resignation_date"
    t.string "state"
    t.bigint "tenant_id", null: false
    t.string "uan_number"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["department_id"], name: "index_employees_on_department_id"
    t.index ["designation_id"], name: "index_employees_on_designation_id"
    t.index ["employment_status"], name: "index_employees_on_employment_status"
    t.index ["reporting_manager_id"], name: "index_employees_on_reporting_manager_id"
    t.index ["tenant_id", "email"], name: "index_employees_on_tenant_id_and_email", unique: true
    t.index ["tenant_id", "employee_code"], name: "index_employees_on_tenant_id_and_employee_code", unique: true
    t.index ["tenant_id"], name: "index_employees_on_tenant_id"
    t.index ["user_id"], name: "index_employees_on_user_id"
  end

  create_table "holidays", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.boolean "is_active", default: true, null: false
    t.string "name", null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "date"], name: "index_holidays_on_tenant_id_and_date", unique: true
    t.index ["tenant_id"], name: "index_holidays_on_tenant_id"
  end

  create_table "investment_declarations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "declared_amount", precision: 10, scale: 2, null: false
    t.string "description", null: false
    t.string "section", null: false
    t.bigint "tax_declaration_id", null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.decimal "verified_amount", precision: 10, scale: 2
    t.index ["tax_declaration_id", "section"], name: "idx_inv_decl_td_section"
    t.index ["tax_declaration_id"], name: "index_investment_declarations_on_tax_declaration_id"
    t.index ["tenant_id"], name: "index_investment_declarations_on_tenant_id"
  end

  create_table "leave_balances", force: :cascade do |t|
    t.decimal "carried_forward_days", precision: 5, scale: 1, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.bigint "employee_id", null: false
    t.string "financial_year", null: false
    t.bigint "leave_type_id", null: false
    t.decimal "remaining_days", precision: 5, scale: 1, default: "0.0", null: false
    t.bigint "tenant_id", null: false
    t.decimal "total_days", precision: 5, scale: 1, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.decimal "used_days", precision: 5, scale: 1, default: "0.0", null: false
    t.index ["employee_id", "leave_type_id", "financial_year"], name: "idx_leave_bal_emp_type_fy", unique: true
    t.index ["employee_id"], name: "index_leave_balances_on_employee_id"
    t.index ["leave_type_id"], name: "index_leave_balances_on_leave_type_id"
    t.index ["tenant_id"], name: "index_leave_balances_on_tenant_id"
  end

  create_table "leave_requests", force: :cascade do |t|
    t.datetime "approved_at"
    t.bigint "approved_by_id"
    t.datetime "created_at", null: false
    t.bigint "employee_id", null: false
    t.date "from_date", null: false
    t.bigint "leave_type_id", null: false
    t.decimal "number_of_days", precision: 5, scale: 1, null: false
    t.text "reason"
    t.text "rejection_reason"
    t.integer "status", default: 0, null: false
    t.bigint "tenant_id", null: false
    t.date "to_date", null: false
    t.datetime "updated_at", null: false
    t.index ["approved_by_id"], name: "index_leave_requests_on_approved_by_id"
    t.index ["employee_id", "from_date", "to_date"], name: "index_leave_requests_on_employee_id_and_from_date_and_to_date"
    t.index ["employee_id"], name: "index_leave_requests_on_employee_id"
    t.index ["leave_type_id"], name: "index_leave_requests_on_leave_type_id"
    t.index ["tenant_id", "status"], name: "index_leave_requests_on_tenant_id_and_status"
    t.index ["tenant_id"], name: "index_leave_requests_on_tenant_id"
  end

  create_table "leave_types", force: :cascade do |t|
    t.decimal "annual_quota", precision: 5, scale: 1, default: "0.0"
    t.boolean "carry_forward", default: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.boolean "is_active", default: true, null: false
    t.boolean "is_paid", default: true, null: false
    t.decimal "max_carry_forward", precision: 5, scale: 1, default: "0.0"
    t.string "name", null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "code"], name: "index_leave_types_on_tenant_id_and_code", unique: true
    t.index ["tenant_id"], name: "index_leave_types_on_tenant_id"
  end

  create_table "payroll_runs", force: :cascade do |t|
    t.datetime "approved_at"
    t.bigint "approved_by_id"
    t.datetime "created_at", null: false
    t.bigint "initiated_by_id", null: false
    t.integer "month", null: false
    t.text "notes"
    t.integer "processed_employees", default: 0
    t.text "rejection_reason"
    t.string "status", default: "draft", null: false
    t.bigint "tenant_id", null: false
    t.decimal "total_deductions", precision: 12, scale: 2, default: "0.0"
    t.integer "total_employees", default: 0
    t.decimal "total_employer_cost", precision: 12, scale: 2, default: "0.0"
    t.decimal "total_gross", precision: 12, scale: 2, default: "0.0"
    t.decimal "total_net_pay", precision: 12, scale: 2, default: "0.0"
    t.datetime "updated_at", null: false
    t.integer "year", null: false
    t.index ["approved_by_id"], name: "index_payroll_runs_on_approved_by_id"
    t.index ["initiated_by_id"], name: "index_payroll_runs_on_initiated_by_id"
    t.index ["tenant_id", "month", "year"], name: "idx_payroll_run_tenant_month_year", unique: true
    t.index ["tenant_id", "status"], name: "idx_payroll_runs_tenant_status"
    t.index ["tenant_id"], name: "index_payroll_runs_on_tenant_id"
  end

  create_table "payroll_settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "esi_ceiling", precision: 10, scale: 2, default: "21000.0"
    t.decimal "esi_employee_rate", precision: 5, scale: 2, default: "0.75"
    t.decimal "esi_employer_rate", precision: 5, scale: 2, default: "3.25"
    t.boolean "esi_enabled", default: true, null: false
    t.decimal "pf_admin_charge_rate", precision: 5, scale: 2, default: "0.5", null: false
    t.decimal "pf_edli_rate", precision: 5, scale: 2, default: "0.5", null: false
    t.decimal "pf_employee_rate", precision: 5, scale: 2, default: "12.0"
    t.decimal "pf_employer_rate", precision: 5, scale: 2, default: "12.0"
    t.boolean "pf_enabled", default: true, null: false
    t.boolean "pf_include_da", default: true, null: false
    t.decimal "pf_wage_ceiling", precision: 10, scale: 2, default: "15000.0"
    t.boolean "pro_rate_leaves", default: true, null: false
    t.boolean "pt_enabled", default: true, null: false
    t.string "pt_state"
    t.boolean "tds_enabled", default: true, null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.string "week_off_pattern", default: "all_saturdays_sundays", null: false
    t.index ["tenant_id"], name: "index_payroll_settings_on_tenant_id", unique: true
  end

  create_table "payslip_line_items", force: :cascade do |t|
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.string "category"
    t.string "component_name", null: false
    t.string "component_type", null: false
    t.datetime "created_at", null: false
    t.decimal "full_amount", precision: 12, scale: 2
    t.bigint "payslip_id", null: false
    t.integer "sort_order", default: 0
    t.datetime "updated_at", null: false
    t.index ["payslip_id", "component_type"], name: "index_payslip_line_items_on_payslip_id_and_component_type"
    t.index ["payslip_id"], name: "index_payslip_line_items_on_payslip_id"
  end

  create_table "payslips", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "employee_id", null: false
    t.decimal "employer_esi", precision: 10, scale: 2, default: "0.0"
    t.decimal "employer_pf", precision: 10, scale: 2, default: "0.0"
    t.decimal "gross_pay", precision: 12, scale: 2, default: "0.0", null: false
    t.boolean "is_revised", default: false
    t.decimal "lop_days", precision: 5, scale: 1, default: "0.0"
    t.integer "month", null: false
    t.decimal "net_pay", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "paid_days", precision: 5, scale: 1, null: false
    t.bigint "payroll_run_id", null: false
    t.text "revision_notes"
    t.string "status", default: "generated", null: false
    t.bigint "tenant_id", null: false
    t.decimal "total_deductions", precision: 12, scale: 2, default: "0.0", null: false
    t.integer "total_working_days", null: false
    t.datetime "updated_at", null: false
    t.integer "year", null: false
    t.index ["employee_id", "month", "year"], name: "index_payslips_on_employee_id_and_month_and_year"
    t.index ["employee_id"], name: "index_payslips_on_employee_id"
    t.index ["payroll_run_id", "employee_id"], name: "index_payslips_on_payroll_run_id_and_employee_id", unique: true
    t.index ["payroll_run_id", "status"], name: "idx_payslips_run_status"
    t.index ["payroll_run_id"], name: "index_payslips_on_payroll_run_id"
    t.index ["tenant_id"], name: "index_payslips_on_tenant_id"
  end

  create_table "platform_admins", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.citext "email", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_platform_admins_on_email", unique: true
  end

  create_table "professional_tax_slabs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "month"
    t.decimal "salary_from", precision: 10, scale: 2, null: false
    t.decimal "salary_to", precision: 10, scale: 2, null: false
    t.string "state", null: false
    t.decimal "tax_amount", precision: 10, scale: 2, null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "state", "month"], name: "idx_pt_slabs_tenant_state_month"
    t.index ["tenant_id"], name: "index_professional_tax_slabs_on_tenant_id"
  end

  create_table "roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.bigint "resource_id"
    t.string "resource_type"
    t.datetime "updated_at", null: false
    t.index ["name", "resource_type", "resource_id"], name: "index_roles_on_name_and_resource_type_and_resource_id"
    t.index ["resource_type", "resource_id"], name: "index_roles_on_resource"
  end

  create_table "salary_components", force: :cascade do |t|
    t.boolean "active", default: true
    t.string "calculation_type", null: false
    t.string "component_type", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "sort_order", default: 0
    t.boolean "taxable", default: true
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "name"], name: "index_salary_components_on_tenant_id_and_name", unique: true
    t.index ["tenant_id"], name: "index_salary_components_on_tenant_id"
  end

  create_table "salary_structure_components", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "salary_component_id", null: false
    t.bigint "salary_structure_id", null: false
    t.datetime "updated_at", null: false
    t.decimal "value", precision: 10, scale: 2, null: false
    t.index ["salary_component_id"], name: "index_salary_structure_components_on_salary_component_id"
    t.index ["salary_structure_id", "salary_component_id"], name: "idx_structure_components_unique", unique: true
    t.index ["salary_structure_id"], name: "index_salary_structure_components_on_salary_structure_id"
  end

  create_table "salary_structures", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "name"], name: "index_salary_structures_on_tenant_id_and_name", unique: true
    t.index ["tenant_id"], name: "index_salary_structures_on_tenant_id"
  end

  create_table "tax_declarations", force: :cascade do |t|
    t.boolean "claiming_hra", default: false, null: false
    t.datetime "created_at", null: false
    t.bigint "employee_id", null: false
    t.decimal "estimated_annual_tax", precision: 12, scale: 2, default: "0.0"
    t.decimal "estimated_monthly_tds", precision: 10, scale: 2, default: "0.0"
    t.string "financial_year", null: false
    t.decimal "home_loan_interest", precision: 10, scale: 2, default: "0.0"
    t.decimal "home_loan_principal", precision: 10, scale: 2, default: "0.0"
    t.string "landlord_name"
    t.string "landlord_pan"
    t.decimal "monthly_rent", precision: 10, scale: 2, default: "0.0"
    t.integer "regime", default: 1, null: false
    t.string "rental_city"
    t.integer "status", default: 0, null: false
    t.bigint "tenant_id", null: false
    t.decimal "total_declared_investments", precision: 12, scale: 2, default: "0.0"
    t.decimal "total_exempt_allowances", precision: 12, scale: 2, default: "0.0"
    t.datetime "updated_at", null: false
    t.index ["employee_id", "financial_year"], name: "idx_tax_decl_emp_fy", unique: true
    t.index ["employee_id", "status"], name: "idx_tax_decl_emp_status"
    t.index ["employee_id"], name: "index_tax_declarations_on_employee_id"
    t.index ["tenant_id"], name: "index_tax_declarations_on_tenant_id"
  end

  create_table "tenant_users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["tenant_id", "user_id"], name: "index_tenant_users_on_tenant_id_and_user_id", unique: true
    t.index ["tenant_id"], name: "index_tenant_users_on_tenant_id"
    t.index ["user_id"], name: "index_tenant_users_on_user_id"
  end

  create_table "tenants", force: :cascade do |t|
    t.string "activation_token"
    t.datetime "activation_token_expires_at"
    t.string "address"
    t.string "city"
    t.datetime "created_at", null: false
    t.string "esi_code"
    t.string "gstin"
    t.string "invite_token"
    t.datetime "invite_token_expires_at"
    t.string "name", null: false
    t.string "pan"
    t.string "pf_establishment_code"
    t.string "pincode"
    t.string "state"
    t.string "status", default: "trial", null: false
    t.citext "subdomain", null: false
    t.string "tan"
    t.datetime "updated_at", null: false
    t.index ["activation_token"], name: "index_tenants_on_activation_token", unique: true
    t.index ["invite_token"], name: "index_tenants_on_invite_token", unique: true
    t.index ["status"], name: "index_tenants_on_status"
    t.index ["subdomain"], name: "index_tenants_on_subdomain", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.boolean "account_active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "first_name", null: false
    t.datetime "invitation_accepted_at"
    t.datetime "invitation_created_at"
    t.integer "invitation_limit"
    t.datetime "invitation_sent_at"
    t.string "invitation_token"
    t.integer "invitations_count", default: 0
    t.bigint "invited_by_id"
    t.string "invited_by_type"
    t.string "last_name", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["invitation_token"], name: "index_users_on_invitation_token", unique: true
    t.index ["invitations_count"], name: "index_users_on_invitations_count"
    t.index ["invited_by_type", "invited_by_id"], name: "index_users_on_invited_by"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "users_roles", id: false, force: :cascade do |t|
    t.bigint "role_id"
    t.bigint "user_id"
    t.index ["role_id"], name: "index_users_roles_on_role_id"
    t.index ["user_id", "role_id"], name: "index_users_roles_on_user_id_and_role_id", unique: true
    t.index ["user_id"], name: "index_users_roles_on_user_id"
  end

  create_table "versions", force: :cascade do |t|
    t.datetime "created_at"
    t.string "event", null: false
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.text "object"
    t.string "whodunnit"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "attendance_summaries", "employees"
  add_foreign_key "attendance_summaries", "tenants"
  add_foreign_key "departments", "tenants"
  add_foreign_key "designations", "tenants"
  add_foreign_key "employee_salaries", "employees"
  add_foreign_key "employee_salaries", "salary_structures"
  add_foreign_key "employee_salaries", "tenants"
  add_foreign_key "employees", "departments"
  add_foreign_key "employees", "designations"
  add_foreign_key "employees", "employees", column: "reporting_manager_id"
  add_foreign_key "employees", "tenants"
  add_foreign_key "employees", "users"
  add_foreign_key "holidays", "tenants"
  add_foreign_key "investment_declarations", "tax_declarations"
  add_foreign_key "investment_declarations", "tenants"
  add_foreign_key "leave_balances", "employees"
  add_foreign_key "leave_balances", "leave_types"
  add_foreign_key "leave_balances", "tenants"
  add_foreign_key "leave_requests", "employees"
  add_foreign_key "leave_requests", "leave_types"
  add_foreign_key "leave_requests", "tenants"
  add_foreign_key "leave_requests", "users", column: "approved_by_id"
  add_foreign_key "leave_types", "tenants"
  add_foreign_key "payroll_runs", "tenants"
  add_foreign_key "payroll_runs", "users", column: "approved_by_id"
  add_foreign_key "payroll_runs", "users", column: "initiated_by_id"
  add_foreign_key "payroll_settings", "tenants"
  add_foreign_key "payslip_line_items", "payslips"
  add_foreign_key "payslips", "employees"
  add_foreign_key "payslips", "payroll_runs"
  add_foreign_key "payslips", "tenants"
  add_foreign_key "professional_tax_slabs", "tenants"
  add_foreign_key "salary_components", "tenants"
  add_foreign_key "salary_structure_components", "salary_components"
  add_foreign_key "salary_structure_components", "salary_structures"
  add_foreign_key "salary_structures", "tenants"
  add_foreign_key "tax_declarations", "employees"
  add_foreign_key "tax_declarations", "tenants"
  add_foreign_key "tenant_users", "tenants"
  add_foreign_key "tenant_users", "users"
end
