module Tenants
  class TenantOnboarder
    Result = Struct.new(:success?, :tenant, :user, :error, keyword_init: true)

    def self.call(signup_form)
      new(signup_form).call
    end

    def initialize(signup_form)
      @form = signup_form
    end

    def call
      tenant = nil
      user = nil

      ActiveRecord::Base.transaction do
        tenant = create_tenant
        user = create_user
        create_tenant_user(tenant, user)
        assign_role(user)
        seed_payroll_setting(tenant)
        seed_salary_components(tenant)
        seed_leave_types(tenant)
        seed_professional_tax_slabs(tenant)
      end

      Result.new(success?: true, tenant: tenant, user: user)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success?: false, error: e.message)
    rescue StandardError => e
      Result.new(success?: false, error: "Something went wrong. Please try again.")
    end

    private

    def create_tenant
      Tenant.create!(
        name: @form.company_name,
        subdomain: @form.subdomain.downcase,
        state: @form.state,
        status: "trial"
      )
    end

    def create_user
      User.create!(
        first_name: @form.first_name,
        last_name: @form.last_name,
        email: @form.email,
        password: @form.password,
        password_confirmation: @form.password_confirmation
      )
    end

    def create_tenant_user(tenant, user)
      TenantUser.create!(tenant: tenant, user: user)
    end

    def assign_role(user)
      user.assign_role(:super_admin)
    end

    def seed_payroll_setting(tenant)
      PayrollSetting.create!(
        tenant: tenant,
        pf_employee_rate: 12.0,
        pf_employer_rate: 12.0,
        pf_ceiling: 15_000,
        esi_employee_rate: 0.75,
        esi_employer_rate: 3.25,
        esi_ceiling: 21_000,
        state: @form.state
      )
    end

    def seed_salary_components(tenant)
      components = [
        # Earnings
        { name: "Basic", component_type: "earning", calculation_type: "percentage", taxable: true, sort_order: 1 },
        { name: "HRA", component_type: "earning", calculation_type: "percentage", taxable: true, sort_order: 2 },
        { name: "DA", component_type: "earning", calculation_type: "percentage", taxable: true, sort_order: 3 },
        { name: "Conveyance Allowance", component_type: "earning", calculation_type: "flat", taxable: false, sort_order: 4 },
        { name: "Medical Allowance", component_type: "earning", calculation_type: "flat", taxable: false, sort_order: 5 },
        { name: "Special Allowance", component_type: "earning", calculation_type: "flat", taxable: true, sort_order: 6 },
        # Deductions
        { name: "Employee PF", component_type: "deduction", calculation_type: "percentage", taxable: false, sort_order: 7 },
        { name: "ESI", component_type: "deduction", calculation_type: "percentage", taxable: false, sort_order: 8 },
        { name: "Professional Tax", component_type: "deduction", calculation_type: "flat", taxable: false, sort_order: 9 },
        { name: "TDS", component_type: "deduction", calculation_type: "flat", taxable: false, sort_order: 10 },
        # Employer contributions
        { name: "Employer PF", component_type: "employer_contribution", calculation_type: "percentage", taxable: false, sort_order: 11 },
        { name: "Employer ESI", component_type: "employer_contribution", calculation_type: "percentage", taxable: false, sort_order: 12 }
      ]

      components.each do |attrs|
        SalaryComponent.create!(attrs.merge(tenant: tenant))
      end
    end

    def seed_leave_types(tenant)
      leave_types = [
        { name: "Casual Leave", code: "CL", annual_quota: 12, carry_forward: false, max_carry_forward: 0 },
        { name: "Sick Leave", code: "SL", annual_quota: 6, carry_forward: false, max_carry_forward: 0 },
        { name: "Earned Leave", code: "EL", annual_quota: 15, carry_forward: true, max_carry_forward: 10 },
        { name: "Loss of Pay", code: "LOP", annual_quota: 0, carry_forward: false, max_carry_forward: 0 }
      ]

      leave_types.each do |attrs|
        LeaveType.create!(attrs.merge(tenant: tenant))
      end
    end

    def seed_professional_tax_slabs(tenant)
      slabs = case @form.state
              when "Maharashtra"
                [
                  { salary_from: 0, salary_to: 7_500, tax_amount: 0, month: nil },
                  { salary_from: 7_501, salary_to: 10_000, tax_amount: 175, month: nil },
                  { salary_from: 10_001, salary_to: 999_999, tax_amount: 200, month: nil },
                  { salary_from: 10_001, salary_to: 999_999, tax_amount: 300, month: "february" }
                ]
              when "Karnataka"
                [
                  { salary_from: 0, salary_to: 15_000, tax_amount: 0, month: nil },
                  { salary_from: 15_001, salary_to: 999_999, tax_amount: 200, month: nil }
                ]
              else
                []
              end

      slabs.each do |attrs|
        ProfessionalTaxSlab.create!(attrs.merge(tenant: tenant, state: @form.state))
      end
    end
  end
end
