module Admin
  class PayrollRunsController < BaseController
    before_action :set_payroll_run, only: [ :show, :process_payroll, :submit_for_review,
                                            :approve, :reject, :resubmit_for_review,
                                            :reprocess, :mark_paid, :progress,
                                            :download_payslips, :bank_file, :download_bank_file ]

    # GET /admin/payroll_runs
    def index
      authorize PayrollRun
      @payroll_runs = policy_scope(PayrollRun).recent.includes(:initiated_by)
    end

    # GET /admin/payroll_runs/new
    def new
      authorize PayrollRun
      @payroll_run = PayrollRun.new
    end

    # POST /admin/payroll_runs
    def create
      authorize PayrollRun
      @payroll_run = PayrollRun.new(payroll_run_params)
      @payroll_run.initiated_by = current_user

      if @payroll_run.save
        redirect_to admin_payroll_run_path(@payroll_run),
                    notice: "Payroll run created for #{@payroll_run.period_label}."
      else
        render :new, status: :unprocessable_entity
      end
    end

    # GET /admin/payroll_runs/:id
    def show
      authorize @payroll_run
    end

    # POST /admin/payroll_runs/:id/process_payroll
    # Enqueues the background job — HR sees live progress bar
    def process_payroll
      authorize @payroll_run

      @payroll_run.with_lock do
        unless @payroll_run.may_start_processing?
          return redirect_to admin_payroll_run_path(@payroll_run),
                             alert: "Payroll run cannot be processed in its current state."
        end
        @payroll_run.start_processing!
        PayrollProcessingJob.perform_later(@payroll_run.id)
      end

      redirect_to admin_payroll_run_path(@payroll_run),
                  notice: "Processing started. This page will update automatically."
    end

    # PATCH /admin/payroll_runs/:id/submit_for_review
    def submit_for_review
      authorize @payroll_run

      if @payroll_run.submit_for_review!
        PayrollMailer.submitted_for_review(@payroll_run).deliver_later
        redirect_to admin_payroll_run_path(@payroll_run),
                    notice: "Payroll submitted for review. Super admins have been notified."
      else
        redirect_to admin_payroll_run_path(@payroll_run),
                    alert: "Could not submit for review."
      end
    end

    # PATCH /admin/payroll_runs/:id/approve
    def approve
      authorize @payroll_run

      @payroll_run.with_lock do
        @payroll_run.approve!
        @payroll_run.record_approval(current_user)
        @payroll_run.payslips.update_all(status: "locked")
      end

      redirect_to admin_payroll_run_path(@payroll_run),
                  notice: "Payroll approved for #{@payroll_run.period_label}. Payslips are now locked."
    end

    # PATCH /admin/payroll_runs/:id/reject
    def reject
      authorize @payroll_run

      @payroll_run.with_lock do
        @payroll_run.update!(rejection_reason: params[:rejection_reason])
        @payroll_run.reject!
        PayrollMailer.rejected(@payroll_run).deliver_later
      end

      redirect_to admin_payroll_run_path(@payroll_run),
                  alert: "Payroll rejected. HR has been notified."
    end

    # PATCH /admin/payroll_runs/:id/resubmit_for_review
    def resubmit_for_review
      authorize @payroll_run

      @payroll_run.resubmit_for_review!
      PayrollMailer.submitted_for_review(@payroll_run).deliver_later

      redirect_to admin_payroll_run_path(@payroll_run),
                  notice: "Payroll resubmitted for review. Super admins have been notified."
    end

    # PATCH /admin/payroll_runs/:id/reprocess
    # Clears all payslips and resets to draft for a fresh run
    def reprocess
      authorize @payroll_run

      @payroll_run.reprocess!

      redirect_to admin_payroll_run_path(@payroll_run),
                  notice: "Payroll reset to draft. You can now process it again."
    end

    # PATCH /admin/payroll_runs/:id/mark_paid
    def mark_paid
      authorize @payroll_run

      @payroll_run.mark_paid!

      redirect_to admin_payroll_run_path(@payroll_run),
                  notice: "Payroll marked as paid for #{@payroll_run.period_label}."
    end

    # GET /admin/payroll_runs/:id/bank_file
    def bank_file
      authorize @payroll_run, :show?
      generator = build_generator("generic_csv")  # default for warnings check
      @missing   = generator.employees_missing_bank_details
    end

    # GET /admin/payroll_runs/:id/download_bank_file?bank=hdfc
    def download_bank_file
      authorize @payroll_run, :show?

      bank   = params[:bank].presence || "generic_csv"
      generator = build_generator(bank)
      content   = generator.call

      ext, mime = file_meta(bank)
      filename  = "salary_#{@payroll_run.period_label.gsub(' ', '_')}_#{bank}.#{ext}"
      send_data content, filename: filename, type: mime, disposition: "attachment"
    rescue Payroll::BankFileGenerators::BankFileError => e
      redirect_to bank_file_admin_payroll_run_path(@payroll_run), alert: e.message
    end

    # GET /admin/payroll_runs/:id/download_payslips
    def download_payslips
      authorize @payroll_run, :show?
      zip_path = Payroll::BulkPayslipPdfGenerator.new(payroll_run: @payroll_run).call
      filename = "payslips_#{@payroll_run.period_label.gsub(' ', '_')}.zip"
      send_file zip_path, filename: filename, type: "application/zip", disposition: "attachment"
    end

    # GET /admin/payroll_runs/:id/progress
    # Turbo Stream source — streams _progress partial updates
    def progress
      authorize @payroll_run
      render partial: "progress", locals: { payroll_run: @payroll_run }
    end

    private

    def set_payroll_run
      @payroll_run = policy_scope(PayrollRun).find(params[:id])
    end

    def payroll_run_params
      params.require(:payroll_run).permit(:month, :year, :notes)
    end

    BANK_GENERATORS = {
      "hdfc"        => Payroll::BankFileGenerators::Hdfc,
      "icici"       => Payroll::BankFileGenerators::Icici,
      "sbi"         => Payroll::BankFileGenerators::Sbi,
      "generic_csv" => Payroll::BankFileGenerators::GenericCsv
    }.freeze

    def build_generator(bank)
      klass = BANK_GENERATORS[bank] || Payroll::BankFileGenerators::GenericCsv
      klass.new(payroll_run: @payroll_run)
    end

    def file_meta(bank)
      bank == "generic_csv" ? [ "csv", "text/csv" ] : [ "txt", "text/plain" ]
    end
  end
end
