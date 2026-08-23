module Admin
  class FullAndFinalPayrollRunsController < BaseController
    before_action :set_payroll_run, only: [ :add_employee ]

    # A settlement run starts empty: employees are added one at a time from the
    # run's edit page, because each exit has its own last working date and its
    # own previewed amounts. See #add_employee.
    def new
      authorize PayrollRun
      today = Date.current
      @payroll_run = PayrollRun.new(
        run_type: "full_and_final",
        title: "Full & Final Settlement",
        payment_date: today,
        month: today.month,
        year: today.year
      )
    end

    def create
      authorize PayrollRun
      @payroll_run = PayrollRun.new(payroll_run_params)
      @payroll_run.run_type = "full_and_final"
      @payroll_run.initiated_by = current_user
      assign_period

      if @payroll_run.save
        redirect_to edit_admin_off_cycle_payroll_run_path(@payroll_run),
                    notice: "Settlement run created. Add the employees you are settling."
      else
        render :new, status: :unprocessable_entity
      end
    end

    # Previews one employee against their last working date and appends the
    # result to the draft as an editable settlement. HR reviews every suggested
    # amount on the edit page before the run is calculated.
    def add_employee
      authorize @payroll_run, :update?

      unless @payroll_run.draft?
        return redirect_to admin_off_cycle_payroll_run_path(@payroll_run),
                           alert: "Employees can only be added while the run is in draft."
      end

      employee = policy_scope(Employee).find_by(id: params[:employee_id])
      last_working_date = parsed_date(params[:last_working_date])

      if employee.nil? || last_working_date.nil?
        return redirect_to edit_admin_off_cycle_payroll_run_path(@payroll_run),
                           alert: "Select an employee and a last working date."
      end

      settlement = build_settlement(employee, last_working_date)

      if settlement.save
        redirect_to edit_admin_off_cycle_payroll_run_path(@payroll_run),
                    notice: notice_for(employee, settlement)
      else
        redirect_to edit_admin_off_cycle_payroll_run_path(@payroll_run),
                    alert: settlement.errors.full_messages.to_sentence
      end
    end

    private

    def set_payroll_run
      @payroll_run = policy_scope(PayrollRun).off_cycle.find(params[:id])
    end

    def payroll_run_params
      params.require(:payroll_run).permit(:title, :payment_date, :notes)
    end

    def build_settlement(employee, last_working_date)
      preview = Payroll::FullAndFinalPreview.new(
        employee: employee, last_working_date: last_working_date
      ).call

      @payroll_run.full_and_final_settlements.build(
        tenant: ActsAsTenant.current_tenant,
        employee: employee,
        last_working_date: last_working_date,
        salary_days: preview.salary_days,
        earned_salary: preview.earned_salary,
        leave_encashment_days: preview.leave_encashment_days,
        leave_encashment: preview.leave_encashment
      ).tap { |s| @preview_warnings = preview.warnings }
    end

    def notice_for(employee, settlement)
      base = "#{employee.full_name} added to the settlement run."
      return base if @preview_warnings.blank?

      "#{base} Review required: #{@preview_warnings.to_sentence}"
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
