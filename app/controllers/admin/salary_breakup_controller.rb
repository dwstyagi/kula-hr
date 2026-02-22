module Admin
  class SalaryBreakupController < BaseController
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    def show
      structure = SalaryStructure.find_by(id: params[:salary_structure_id])
      annual_ctc = params[:annual_ctc].to_d

      if structure.nil? || annual_ctc < 100_000
        render json: { error: "Select a structure and enter a valid CTC" }, status: :unprocessable_content
        return
      end

      payroll_setting = ActsAsTenant.current_tenant.payroll_setting
      pt_slabs = ProfessionalTaxSlab.where(month: nil).order(:salary_from)

      result = Salary::CtcBreakupCalculator.call(
        annual_ctc: annual_ctc,
        salary_structure: structure,
        payroll_setting: payroll_setting,
        professional_tax_slabs: pt_slabs
      )

      render json: {
        monthly_ctc: result.monthly_ctc,
        earnings: result.earnings.map { |e| { name: e.name, monthly: e.monthly, annual: e.annual } },
        gross_monthly: result.gross_monthly,
        gross_annual: result.gross_annual,
        deductions: result.deductions.map { |d| { name: d.name, monthly: d.monthly, annual: d.annual } },
        total_deductions_monthly: result.total_deductions_monthly,
        employer_contributions: result.employer_contributions.map { |c| { name: c.name, monthly: c.monthly, annual: c.annual } },
        total_employer_monthly: result.total_employer_monthly,
        net_monthly: result.net_monthly,
        net_annual: result.net_annual
      }
    end
  end
end
