module Admin
  class OffCyclePayrollRunsController < BaseController
    before_action :require_feature!
    before_action :set_payroll_run, only: [ :show, :edit, :update, :process_payroll, :submit_for_review,
                                            :approve, :reject, :resubmit_for_review,
                                            :reprocess, :mark_paid, :bank_file,
                                            :download_bank_file ]

    def index
      authorize PayrollRun
      @payroll_runs = PayrollRunPresenter.wrap(
        policy_scope(PayrollRun).off_cycle.includes(:initiated_by, :approved_by)
          .order(payment_date: :desc, created_at: :desc)
      )
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
      redirect_unless_draft unless @payroll_run.draft?
    end

    def update
      authorize @payroll_run
      return redirect_unless_draft unless @payroll_run.draft?

      @payroll_run.assign_attributes(payroll_run_params)
      assign_period_from_payment_date
      if @payroll_run.save
        redirect_to admin_off_cycle_payroll_run_path(@payroll_run), notice: "Payment inputs updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def process_payroll
      authorize @payroll_run
      @payroll_run.with_lock do
        unless @payroll_run.may_start_processing?
          return redirect_to admin_off_cycle_payroll_run_path(@payroll_run),
                             alert: "This run cannot be processed in its current state."
        end

        @payroll_run.start_processing!
        PayrollProcessingJob.perform_later(@payroll_run.id)
      end
      redirect_to admin_off_cycle_payroll_run_path(@payroll_run), notice: "Processing started."
    end

    def submit_for_review
      authorize @payroll_run
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
      end
      redirect_to admin_off_cycle_payroll_run_path(@payroll_run), notice: "Off-cycle payroll approved."
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
      @payroll_run.resubmit_for_review!
      PayrollMailer.submitted_for_review(@payroll_run).deliver_later
      redirect_to admin_off_cycle_payroll_run_path(@payroll_run), notice: "Resubmitted for review."
    end

    def reprocess
      authorize @payroll_run
      @payroll_run.reprocess!
      redirect_to admin_off_cycle_payroll_run_path(@payroll_run), notice: "Run reset. You can process it again."
    end

    def mark_paid
      authorize @payroll_run
      @payroll_run.mark_paid!
      redirect_to admin_off_cycle_payroll_run_path(@payroll_run), notice: "Off-cycle payroll marked as paid."
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
      content = generator.call
      ext, mime = Payroll::BankFileGenerators::Factory.file_meta(bank)
      filename = "off_cycle_#{@payroll_run.id}_#{bank}.#{ext}"
      send_data content, filename: filename, type: mime, disposition: "attachment"
    rescue Payroll::BankFileGenerators::BankFileError => e
      redirect_to bank_file_admin_off_cycle_payroll_run_path(@payroll_run), alert: e.message
    end

    private

    def require_feature!
      return if ActsAsTenant.current_tenant&.off_cycle_payroll_enabled?

      redirect_to admin_payroll_runs_path, alert: "Off-cycle payroll is not enabled for this company."
    end

    def set_payroll_run
      @payroll_run = policy_scope(PayrollRun).off_cycle.find(params[:id])
    end

    def payroll_run_params
      params.require(:payroll_run).permit(
        :run_type, :title, :payment_date, :notes,
        off_cycle_payroll_entries_attributes: [ :id, :employee_id, :gross_amount, :tds_amount, :notes ]
      ).tap do |permitted|
        permitted[:run_type] = "bonus" unless permitted[:run_type].in?(%w[bonus additional])
      end
    end

    def assign_period_from_payment_date
      return if @payroll_run.payment_date.blank?

      @payroll_run.month = @payroll_run.payment_date.month
      @payroll_run.year = @payroll_run.payment_date.year
    end

    def eligible_employees
      Employee.where(employment_status: %w[active probation notice_period])
        .order(:first_name, :last_name)
    end

    def prepare_entries
      existing_employee_ids = @payroll_run.off_cycle_payroll_entries.map(&:employee_id)
      eligible_employees.each do |employee|
        next if existing_employee_ids.include?(employee.id)

        @payroll_run.off_cycle_payroll_entries.build(employee: employee, tenant: ActsAsTenant.current_tenant)
      end
    end


    def redirect_unless_draft
      redirect_to admin_off_cycle_payroll_run_path(@payroll_run),
                  alert: "Payment inputs can only be edited while the run is in draft."
    end
  end
end
