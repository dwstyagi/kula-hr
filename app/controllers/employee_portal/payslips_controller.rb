module EmployeePortal
  class PayslipsController < BaseController
    before_action :require_employee!
    before_action :set_payslip, only: [ :show, :download ]

    # GET /portal/payslips
    def index
      @payslips = portal_payslips
                    .includes(:payroll_run)
                    .order(year: :desc, month: :desc)
                    .limit(24)

      # YTD summary for current financial year
      fy_start = Date.new(FinancialYear.start_year(Date.current), 4, 1)
      @ytd_payslips = portal_payslips
                        .where("(payslips.year > :fy_year) OR (payslips.year = :fy_year AND payslips.month >= :fy_month)",
                               fy_year: fy_start.year, fy_month: fy_start.month)
      # Month-over-month changes
      @mom_changes = {}
      sorted = @payslips.reject(&:off_cycle?)
      sorted.each_with_index do |payslip, i|
        prev = sorted[i + 1]
        if prev && prev.net_pay > 0
          @mom_changes[payslip.id] = ((payslip.net_pay - prev.net_pay) / prev.net_pay * 100).round(1)
        end
      end

      @ytd_gross      = @ytd_payslips.sum(&:gross_pay)
      @ytd_deductions = @ytd_payslips.sum(&:total_deductions)
      @ytd_net        = @ytd_payslips.sum(&:net_pay)
      @ytd_tds        = @ytd_payslips.sum { |p| p.line_items.where(component_name: "TDS").sum(:amount) }
      @ytd_pf         = @ytd_payslips.sum { |p| p.line_items.where(component_name: "PF").sum(:amount) }
    end

    # GET /portal/payslips/:id
    def show
      authorize @payslip
    end

    # GET /portal/payslips/:id/download
    def download
      authorize @payslip, :show?
      pdf = Payroll::PayslipPdfDocument.call(payslip: @payslip)
      filename = "payslip_#{@payslip.employee.employee_code}_#{@payslip.period_label.gsub(' ', '_')}.pdf"
      send_data pdf, filename: filename, type: "application/pdf", disposition: "attachment"
    end

    private

    # The portal shows only the signed-in person's released payslips — also
    # for an HR admin who has an employee profile, whose policy scope in the
    # admin panel covers everyone.
    def portal_payslips
      policy_scope(Payslip).joins(:payroll_run)
        .where(employee: current_employee, payroll_runs: { status: %w[approved paid] })
    end

    def set_payslip
      @payslip = portal_payslips.find(params[:id])
    end

    def require_employee!
      unless current_employee
        redirect_to employee_portal_root_path, alert: "No employee profile found."
      end
    end
  end
end
