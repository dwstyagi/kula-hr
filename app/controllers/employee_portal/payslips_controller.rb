module EmployeePortal
  class PayslipsController < BaseController
    before_action :require_employee!
    before_action :set_payslip, only: [ :show, :download ]

    # GET /portal/payslips
    def index
      @payslips = policy_scope(Payslip)
                    .includes(:payroll_run)
                    .order(year: :desc, month: :desc)

      # YTD summary for current financial year
      fy_start = Date.today.month >= 4 ? Date.new(Date.today.year, 4, 1) : Date.new(Date.today.year - 1, 4, 1)
      @ytd_payslips = @payslips.select { |p| Date.new(p.year, p.month, 1) >= fy_start }
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
      pdf = Payroll::PayslipPdfGenerator.new(payslip: @payslip).call
      filename = "payslip_#{@payslip.employee.employee_code}_#{@payslip.period_label.gsub(' ', '_')}.pdf"
      send_data pdf, filename: filename, type: "application/pdf", disposition: "attachment"
    end

    private

    def set_payslip
      @payslip = policy_scope(Payslip).find(params[:id])
    end

    def require_employee!
      unless current_employee
        redirect_to employee_portal_root_path, alert: "No employee profile found."
      end
    end
  end
end
