module Admin
  class PayslipsController < BaseController
    before_action :set_payroll_run, only: [ :index ]
    before_action :set_payslip,     only: [ :show, :edit, :update, :download ]

    # GET /admin/payroll_runs/:payroll_run_id/payslips
    def index
      authorize Payslip
      @payslips = policy_scope(Payslip)
        .where(payroll_run: @payroll_run)
        .includes(employee: [ :department, :designation ])
        .order("employees.last_name, employees.first_name")

      # Optional search
      if params[:q].present?
        q = "%#{params[:q].downcase}%"
        @payslips = @payslips.joins(:employee).where(
          "LOWER(employees.first_name || ' ' || employees.last_name) LIKE ? OR LOWER(employees.employee_code) LIKE ?",
          q, q
        )
      end
    end

    # GET /admin/payslips/:id
    def show
      authorize @payslip
    end

    # GET /admin/payslips/:id/download
    def download
      authorize @payslip, :show?
      pdf = Payroll::PayslipPdfGenerator.new(payslip: @payslip).call
      filename = "payslip_#{@payslip.employee.employee_code}_#{@payslip.period_label.gsub(' ', '_')}.pdf"
      send_data pdf, filename: filename, type: "application/pdf", disposition: "attachment"
    end

    # GET /admin/payslips/:id/edit
    def edit
      authorize @payslip
    end

    # PATCH /admin/payslips/:id
    def update
      authorize @payslip

      Payslip.transaction do
        # Update existing line items
        if params[:line_items].present?
          params[:line_items].each do |id, attrs|
            line_item = @payslip.line_items.find(id)
            line_item.update!(amount: attrs[:amount].to_d)
          end
        end

        # Add new line items
        if params[:new_line_items].present?
          params[:new_line_items].each do |_, attrs|
            next if attrs[:component_name].blank? || attrs[:amount].blank?
            @payslip.line_items.create!(
              component_name: attrs[:component_name],
              component_type: attrs[:component_type],
              amount:         attrs[:amount].to_d,
              sort_order:     @payslip.line_items.maximum(:sort_order).to_i + 1,
              category:       "variable"
            )
          end
        end

        # Remove deleted line items
        if params[:remove_line_items].present?
          @payslip.line_items.where(id: params[:remove_line_items]).destroy_all
        end

        @payslip.update!(
          is_revised:     true,
          revision_notes: params[:revision_notes],
          status:         "revised"
        )

        @payslip.recalculate_totals!
        update_payroll_run_totals
      end

      redirect_to admin_payslip_path(@payslip),
                  notice: "Payslip updated and totals recalculated."
    rescue ActiveRecord::RecordInvalid => e
      flash.now[:alert] = e.message
      render :edit, status: :unprocessable_entity
    end

    private

    def set_payroll_run
      @payroll_run = policy_scope(PayrollRun).find(params[:payroll_run_id])
    end

    def set_payslip
      @payslip     = policy_scope(Payslip).find(params[:id])
      @payroll_run = @payslip.payroll_run
    end

    # Recalculate the PayrollRun aggregate totals after a payslip edit
    def update_payroll_run_totals
      @payroll_run.update!(
        total_gross:       @payroll_run.payslips.sum(:gross_pay),
        total_deductions:  @payroll_run.payslips.sum(:total_deductions),
        total_net_pay:     @payroll_run.payslips.sum(:net_pay),
        total_employer_cost: @payroll_run.payslips.sum(:employer_pf) +
                             @payroll_run.payslips.sum(:employer_esi)
      )
    end
  end
end
