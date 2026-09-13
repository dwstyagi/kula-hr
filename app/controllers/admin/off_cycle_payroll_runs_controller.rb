module Admin
  class OffCyclePayrollRunsController < BaseController
    before_action :set_payroll_run, only: [ :show, :edit, :update, :process_payroll, :submit_for_review,
                                            :approve, :reject, :resubmit_for_review,
                                            :reprocess, :mark_paid, :bank_file,
                                            :download_bank_file, :destroy ]
    before_action :set_any_payroll_run, only: [ :restore ]
    before_action :check_input_limit, only: [ :create, :update ]

    def index
      authorize PayrollRun
      @showing_deleted = params[:filter] == "deleted"
      scope = policy_scope(PayrollRun).off_cycle
      scope = @showing_deleted ? scope.deleted : scope.kept

      @deleted_count = policy_scope(PayrollRun).off_cycle.deleted.count
      @pagy, runs = pagy(:offset, scope.includes(:initiated_by, :approved_by)
        .order(payment_date: :desc, created_at: :desc, id: :desc), limit: 25)
      ids = runs.map(&:id)
      @payslip_counts = Payslip.where(payroll_run_id: ids).group(:payroll_run_id).count
      @entry_counts = OffCyclePayrollEntry.where(payroll_run_id: ids).group(:payroll_run_id).count
      @settlement_counts = FullAndFinalSettlement.where(payroll_run_id: ids).group(:payroll_run_id).count
      @payroll_runs = PayrollRunPresenter.wrap(runs)
    end

    def employee_options
      authorize PayrollRun, :new?
      scope = eligible_employees
      scope = scope.joins(:department).where(departments: { name: params[:department] }) if params[:department].present?
      if params[:q].present?
        term = "%#{Employee.sanitize_sql_like(params[:q].to_s.strip.downcase)}%"
        scope = scope.where("LOWER(first_name || ' ' || last_name || ' ' || employee_code) LIKE ?", term)
      end
      render json: scope.limit(50).map { |e| { id: e.id, name: e.full_name, code: e.employee_code, department: e.department&.name } }
    end

    def new
      authorize PayrollRun
      today = Date.current
      @payroll_run = PayrollRun.new(
        run_type: params[:run_type].in?(%w[bonus additional]) ? params[:run_type] : "bonus",
        title: params[:run_type] == "additional" ? "Additional Payment" : "Performance Bonus",
        payment_date: today,
        month: today.month,
        year: today.year
      )
      prepare_entries
    end

    def create
      authorize PayrollRun
      @payroll_run = PayrollRun.new(payroll_run_params)
      @payroll_run.initiated_by = current_user
      assign_period_from_payment_date
      @payroll_run.off_cycle_payroll_entries.each { |entry| entry.tenant = ActsAsTenant.current_tenant }

      if @payroll_run.save
        redirect_to admin_off_cycle_payroll_run_path(@payroll_run),
                    notice: "#{@payroll_run.run_type_label} run created."
      else
        prepare_entries
        render :new, status: :unprocessable_entity
      end
    end

    def show
      authorize @payroll_run
      @payroll_run = PayrollRunPresenter.new(@payroll_run)
    end

    def edit
      authorize @payroll_run
      return redirect_unless_draft unless @payroll_run.draft?

      @addable_employees = addable_employees if @payroll_run.full_and_final?
    end

    def update
      authorize @payroll_run
      return redirect_unless_draft unless @payroll_run.draft?

      @payroll_run.assign_attributes(payroll_run_params)
      assign_period_from_payment_date
      if @payroll_run.save
        redirect_to admin_off_cycle_payroll_run_path(@payroll_run), notice: "Payment inputs updated."
      else
        @addable_employees = addable_employees if @payroll_run.full_and_final?
        render :edit, status: :unprocessable_entity
      end
    end

    def process_payroll
      authorize @payroll_run
      if @payroll_run.full_and_final? && @payroll_run.full_and_final_settlements.none?
        return redirect_to admin_off_cycle_payroll_run_path(@payroll_run),
                           alert: "Add at least one employee to settle before calculating this run."
      end

      @payroll_run.with_lock do
        unless @payroll_run.may_start_processing?
          return redirect_to admin_off_cycle_payroll_run_path(@payroll_run),
                             alert: "This run cannot be processed in its current state."
        end

        @payroll_run.start_processing!
        JobDispatch.enqueue!(PayrollProcessingJob, @payroll_run.id)
      end
      redirect_to admin_off_cycle_payroll_run_path(@payroll_run), notice: "Processing started."
    end

    def submit_for_review
      authorize @payroll_run
      if @payroll_run.payslips.none?
        return redirect_to admin_off_cycle_payroll_run_path(@payroll_run),
                           alert: "This run has no payslips. Recalculate it before sending it for review."
      end

      @payroll_run.submit_for_review!
      PayrollMailer.submitted_for_review(@payroll_run).deliver_later
      redirect_to admin_off_cycle_payroll_run_path(@payroll_run), notice: "Submitted for review."
    end

    def approve
      authorize @payroll_run
      @payroll_run.with_lock do
        @payroll_run.approve!
        @payroll_run.record_approval(current_user)
        @payroll_run.payslips.update_all(status: "locked")
        @payroll_run.full_and_final_settlements.each(&:close_out_employee!)
      end
      redirect_to admin_off_cycle_payroll_run_path(@payroll_run),
                  notice: @payroll_run.full_and_final? ? "Settlement approved and the employee is closed out of payroll." : "Off-cycle payroll approved."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_off_cycle_payroll_run_path(@payroll_run),
                  alert: "Could not approve: the employee record must be valid to close them out of payroll (#{e.record.errors.full_messages.to_sentence})."
    end

    def reject
      authorize @payroll_run
      @payroll_run.with_lock do
        @payroll_run.update!(rejection_reason: params[:rejection_reason])
        @payroll_run.reject!
        PayrollMailer.rejected(@payroll_run).deliver_later
      end
      redirect_to admin_off_cycle_payroll_run_path(@payroll_run), alert: "Off-cycle payroll rejected."
    end

    def resubmit_for_review
      authorize @payroll_run
      if @payroll_run.payslips.none?
        return redirect_to admin_off_cycle_payroll_run_path(@payroll_run),
                           alert: "This run has no payslips. Recalculate it before sending it for review."
      end

      @payroll_run.resubmit_for_review!
      PayrollMailer.submitted_for_review(@payroll_run).deliver_later
      redirect_to admin_off_cycle_payroll_run_path(@payroll_run), notice: "Resubmitted for review."
    end

    def reprocess
      authorize @payroll_run
      task = @payroll_run.enqueue_reset!(user: current_user)
      redirect_to admin_background_task_path(task), notice: "Payroll reset queued."
    end

    def mark_paid
      authorize @payroll_run
      @payroll_run.mark_paid!
      redirect_to admin_off_cycle_payroll_run_path(@payroll_run), notice: "Off-cycle payroll marked as paid."
    end

    def destroy
      authorize @payroll_run
      if @payroll_run.soft_delete!
        redirect_to admin_off_cycle_payroll_runs_path,
                    notice: "#{@payroll_run.title} deleted. You can restore it from the Deleted tab."
      else
        redirect_to admin_off_cycle_payroll_run_path(@payroll_run),
                    alert: "Only a draft run can be deleted."
      end
    end

    def restore
      authorize @payroll_run
      @payroll_run.restore!
      redirect_to admin_off_cycle_payroll_run_path(@payroll_run),
                  notice: "#{@payroll_run.title} restored."
    end

    def bank_file
      authorize @payroll_run, :show?
      generator = Payroll::BankFileGenerators::Factory.for(nil, payroll_run: @payroll_run)
      @missing = generator.employees_missing_bank_details
      @payroll_run = PayrollRunPresenter.new(@payroll_run)
    end

    def download_bank_file
      authorize @payroll_run, :download_bank_file?
      bank = params[:bank].presence || "generic_csv"
      generator = Payroll::BankFileGenerators::Factory.for(bank, payroll_run: @payroll_run)
      content = generator.stream
      ext, mime = Payroll::BankFileGenerators::Factory.file_meta(bank)
      filename = "off_cycle_#{@payroll_run.id}_#{bank}.#{ext}"
      stream_download content, filename: filename, type: mime
    rescue Payroll::BankFileGenerators::BankFileError => e
      redirect_to bank_file_admin_off_cycle_payroll_run_path(@payroll_run), alert: e.message
    end

    private

    def set_payroll_run
      @payroll_run = policy_scope(PayrollRun).off_cycle.kept.find(params[:id])
    end

    # Restore is the one action that has to reach a deleted run.
    def set_any_payroll_run
      @payroll_run = policy_scope(PayrollRun).off_cycle.find(params[:id])
    end

    def payroll_run_params
      params.require(:payroll_run).permit(
        :run_type, :title, :payment_date, :notes,
        off_cycle_payroll_entries_attributes: [ :id, :employee_id, :gross_amount, :tds_amount, :notes, :_destroy ],
        full_and_final_settlements_attributes: [
          :id, :employee_id, :last_working_date, :salary_days, :leave_encashment_days,
          :earned_salary, :leave_encashment, :bonus, :notice_pay, :gratuity, :other_earnings,
          :notice_recovery, :loan_recovery, :asset_recovery, :other_deductions,
          :pf_amount, :esi_amount, :professional_tax_amount, :tds_amount, :notes, :_destroy
        ]
      ).tap do |permitted|
        permitted[:run_type] = if @payroll_run&.full_and_final?
          "full_and_final"
        elsif permitted[:run_type].in?(%w[bonus additional])
          permitted[:run_type]
        else
          "bonus"
        end
      end
    end

    def assign_period_from_payment_date
      return if @payroll_run.payment_date.blank?

      @payroll_run.month = @payroll_run.payment_date.month
      @payroll_run.year = @payroll_run.payment_date.year
    end

    # Anyone who can be settled and is not already in this run. Exited staff stay
    # selectable: a settlement is often raised after the status is updated.
    def addable_employees
      policy_scope(Employee)
        .where(employment_status: %w[active probation notice_period resigned terminated])
        .where.not(id: @payroll_run.full_and_final_settlements.select(:employee_id))
        .order(:first_name, :last_name)
    end

    def eligible_employees
      policy_scope(Employee)
        .where(employment_status: %w[active probation notice_period])
        .includes(:department)
        .order(:first_name, :last_name)
    end

    def prepare_entries
      return if @payroll_run.full_and_final?

      existing_employee_ids = @payroll_run.off_cycle_payroll_entries.map(&:employee_id).to_set
      eligible_employees.limit(50).each do |employee|
        next if existing_employee_ids.include?(employee.id)
        @payroll_run.off_cycle_payroll_entries.build(employee: employee, tenant: ActsAsTenant.current_tenant)
      end
      ActiveRecord::Associations::Preloader.new(records: @payroll_run.off_cycle_payroll_entries.to_a,
        associations: { employee: :department }).call
      @entry_departments = Department.order(:name).limit(100).pluck(:name)
    end


    def check_input_limit
      values = params.dig(:payroll_run, :off_cycle_payroll_entries_attributes)
      if values && (values.respond_to?(:keys) ? values.keys.size : values.size) > 500
        redirect_to admin_off_cycle_payroll_runs_path, alert: "Use at most 500 employee entries per submission."
      end
    end

    def redirect_unless_draft
      redirect_to admin_off_cycle_payroll_run_path(@payroll_run),
                  alert: "Payment inputs can only be edited while the run is in draft."
    end
  end
end
