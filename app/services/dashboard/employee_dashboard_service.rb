module Dashboard
  class EmployeeDashboardService
    Result = Struct.new(
      :latest_payslip, :previous_payslip, :mom_change,
      :tax_declaration, :ytd_gross, :ytd_net, :ytd_pf, :ytd_tds, :ytd_esi, :ytd_pt,
      keyword_init: true
    )

    def initialize(employee:)
      @employee = employee
    end

    def call
      payslips = fetch_payslips
      latest = payslips.first
      previous = payslips.second

      mom = if latest && previous && previous.net_pay > 0
              ((latest.net_pay - previous.net_pay) / previous.net_pay * 100).round(1)
      end

      ytd = ytd_totals

      Result.new(
        latest_payslip: latest,
        previous_payslip: previous,
        mom_change: mom,
        tax_declaration: current_tax_declaration,
        ytd_gross: ytd[:gross],
        ytd_net: ytd[:net],
        ytd_pf: ytd[:pf],
        ytd_tds: ytd[:tds],
        ytd_esi: ytd[:esi],
        ytd_pt: ytd[:pt]
      )
    end

    private

    def fetch_payslips
      Payslip.where(employee: @employee)
             .joins(:payroll_run)
             .where(payroll_runs: { status: %w[approved paid] })
             .order(year: :desc, month: :desc)
             .limit(2)
    end

    def current_tax_declaration
      fy = current_fy
      @employee.tax_declarations.find_by(financial_year: fy)
    end

    def ytd_totals
      fy_start = Date.current.month >= 4 ? Date.new(Date.current.year, 4, 1) : Date.new(Date.current.year - 1, 4, 1)

      payslips = Payslip.where(employee: @employee)
                        .joins(:payroll_run)
                        .where(payroll_runs: { status: %w[approved paid] })

      # Filter to current FY
      fy_payslips = payslips.where(
        "(payslips.year > :start_year) OR (payslips.year = :start_year AND payslips.month >= :start_month)",
        start_year: fy_start.year, start_month: fy_start.month
      )

      totals = fy_payslips.select(
        "COALESCE(SUM(payslips.gross_pay), 0) AS total_gross",
        "COALESCE(SUM(payslips.net_pay), 0) AS total_net"
      ).take

      # Component-wise deduction totals
      deductions = PayslipLineItem.joins(payslip: :payroll_run)
                                  .where(payslips: { employee_id: @employee.id })
                                  .where(payroll_runs: { status: %w[approved paid] })
                                  .where(component_type: "deduction")
                                  .merge(
                                    Payslip.where(
                                      "(payslips.year > :start_year) OR (payslips.year = :start_year AND payslips.month >= :start_month)",
                                      start_year: fy_start.year, start_month: fy_start.month
                                    )
                                  )
                                  .group(:component_name)
                                  .sum(:amount)

      {
        gross: totals&.total_gross.to_f,
        net: totals&.total_net.to_f,
        pf: deductions["PF"].to_f,
        tds: deductions["TDS"].to_f,
        esi: deductions["ESI"].to_f,
        pt: deductions["Professional Tax"].to_f + deductions["PT"].to_f
      }
    end

    def current_fy
      today = Date.current
      if today.month >= 4
        "#{today.year}-#{(today.year + 1).to_s.last(2)}"
      else
        "#{today.year - 1}-#{today.year.to_s.last(2)}"
      end
    end
  end
end
