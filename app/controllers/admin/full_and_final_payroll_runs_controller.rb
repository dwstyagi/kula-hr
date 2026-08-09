module Admin
  class FullAndFinalPayrollRunsController < BaseController
    def new
      authorize PayrollRun
      load_employees
      @selected_employee = @employees.find_by(id: params[:employee_id])
      @last_working_date = parsed_date(params[:last_working_date])
      build_preview if @selected_employee && @last_working_date
    end

    def create
      authorize PayrollRun
      load_employees
      @payroll_run = PayrollRun.new(payroll_run_params)
      @payroll_run.run_type = "full_and_final"
      @payroll_run.initiated_by = current_user
      assign_period

      settlement = @payroll_run.full_and_final_settlement
      if settlement
        settlement.tenant = ActsAsTenant.current_tenant
        settlement.employee = @employees.find_by(id: settlement.employee_id)
      end

      if @payroll_run.save
        redirect_to admin_off_cycle_payroll_run_path(@payroll_run), notice: "Full & Final settlement created."
      else
        @selected_employee = settlement&.employee
        @last_working_date = settlement&.last_working_date
        @preview_warnings = []
        render :new, status: :unprocessable_entity
      end
    end

    private

    def payroll_run_params
      params.require(:payroll_run).permit(
        :title, :payment_date, :notes,
        full_and_final_settlement_attributes: [
          :employee_id, :last_working_date, :salary_days, :leave_encashment_days,
          :earned_salary, :leave_encashment, :bonus, :notice_pay, :gratuity, :other_earnings,
          :notice_recovery, :loan_recovery, :asset_recovery, :other_deductions,
          :pf_amount, :esi_amount, :professional_tax_amount, :tds_amount, :notes
        ]
      )
    end

    def load_employees
      @employees = policy_scope(Employee)
        .where(employment_status: %w[active probation notice_period resigned terminated])
        .order(:first_name, :last_name)
    end

    def build_preview
      preview = Payroll::FullAndFinalPreview.new(
        employee: @selected_employee,
        last_working_date: @last_working_date
      ).call
      payment_date = [ Date.current, @last_working_date ].max
      @preview_warnings = preview.warnings
      @payroll_run = PayrollRun.new(
        run_type: "full_and_final",
        title: "Full & Final - #{@selected_employee.full_name}",
        payment_date: payment_date,
        month: payment_date.month,
        year: payment_date.year
      )
      @payroll_run.build_full_and_final_settlement(
        tenant: ActsAsTenant.current_tenant,
        employee: @selected_employee,
        last_working_date: @last_working_date,
        salary_days: preview.salary_days,
        earned_salary: preview.earned_salary,
        leave_encashment_days: preview.leave_encashment_days,
        leave_encashment: preview.leave_encashment
      )
    end

    def parsed_date(value)
      Date.iso8601(value) if value.present?
    rescue Date::Error
      nil
    end

    def assign_period
      return if @payroll_run.payment_date.blank?

      @payroll_run.month = @payroll_run.payment_date.month
      @payroll_run.year = @payroll_run.payment_date.year
    end
  end
end
