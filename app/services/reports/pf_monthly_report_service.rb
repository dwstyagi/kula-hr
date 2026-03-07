module Reports
  class PfMonthlyReportService
    Row = Struct.new(:uan, :name, :gross_wages, :epf_wages, :eps_wages, :edli_wages,
                     :epf_ee, :eps_er, :epf_er_diff, :ncp_days, :refund,
                     keyword_init: true)

    attr_reader :rows, :summary

    def initialize(month:, year:)
      @month = month
      @year = year
    end

    def call
      run = PayrollRun.where(status: %w[approved paid]).for_month(@month, @year).first
      @rows = []
      @summary = { total_epf_ee: 0, total_eps_er: 0, total_epf_er_diff: 0,
                   total_gross_wages: 0, employee_count: 0 }

      return self unless run

      setting = PayrollSetting.first
      return self unless setting&.pf_enabled?

      pf_wage_ceiling = setting.pf_wage_ceiling || 15_000
      pf_ee_rate = (setting.pf_employee_rate || 12).to_f / 100
      eps_rate = 8.33 / 100.0
      edli_rate = (setting.pf_edli_rate || 0.5).to_f / 100

      payslips = Payslip.where(payroll_run: run)
                        .includes(employee: :department)
                        .joins(:employee)
                        .where(employees: { pf_applicable: true })

      payslips.each do |payslip|
        emp = payslip.employee
        basic = payslip.line_items.find_by(component_name: "Basic", component_type: "earning")&.amount.to_f
        da = payslip.line_items.find_by(component_name: "DA", component_type: "earning")&.amount.to_f
        pf_wages = basic + da

        epf_wages = [ pf_wages, pf_wage_ceiling ].min
        eps_wages = [ pf_wages, pf_wage_ceiling ].min
        edli_wages = [ pf_wages, pf_wage_ceiling ].min

        epf_ee = (epf_wages * pf_ee_rate).round(0)
        eps_er = (eps_wages * eps_rate).round(0)
        epf_er_diff = (epf_ee - eps_er).clamp(0, Float::INFINITY).round(0)

        row = Row.new(
          uan: emp.uan_number || "",
          name: emp.full_name,
          gross_wages: payslip.gross_pay.to_f.round(0),
          epf_wages: epf_wages.round(0),
          eps_wages: eps_wages.round(0),
          edli_wages: edli_wages.round(0),
          epf_ee: epf_ee,
          eps_er: eps_er,
          epf_er_diff: epf_er_diff,
          ncp_days: payslip.lop_days.to_i,
          refund: 0
        )
        @rows << row

        @summary[:total_epf_ee] += epf_ee
        @summary[:total_eps_er] += eps_er
        @summary[:total_epf_er_diff] += epf_er_diff
        @summary[:total_gross_wages] += payslip.gross_pay.to_f
        @summary[:employee_count] += 1
      end

      self
    end

    def to_ecr
      lines = rows.map do |r|
        [ r.uan, r.name, r.gross_wages.to_i, r.epf_wages.to_i, r.eps_wages.to_i,
         r.edli_wages.to_i, r.epf_ee.to_i, r.eps_er.to_i, r.epf_er_diff.to_i,
         r.ncp_days, r.refund ].join("|")
      end
      lines.join("\n")
    end
  end
end
