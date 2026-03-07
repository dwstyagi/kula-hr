require "csv"

module Reports
  class EsiMonthlyReportService
    Row = Struct.new(:employee_code, :name, :gross_wages, :employee_contribution,
                     :employer_contribution, :total_contribution, :ip_number,
                     keyword_init: true)

    attr_reader :rows, :summary

    def initialize(month:, year:)
      @month = month
      @year = year
    end

    def call
      run = PayrollRun.where(status: %w[approved paid]).for_month(@month, @year).first
      @rows = []
      @summary = { total_ee: 0, total_er: 0, total_gross: 0, employee_count: 0 }

      return self unless run

      setting = PayrollSetting.first
      return self unless setting&.esi_enabled?

      esi_ee_rate = (setting.esi_employee_rate || 0.75).to_f / 100
      esi_er_rate = (setting.esi_employer_rate || 3.25).to_f / 100

      payslips = Payslip.where(payroll_run: run)
                        .includes(:employee, :line_items)
                        .joins(:line_items)
                        .where(payslip_line_items: { component_name: "ESI", component_type: "deduction" })
                        .distinct

      payslips.each do |payslip|
        emp = payslip.employee
        esi_deduction = payslip.line_items.find_by(component_name: "ESI", component_type: "deduction")&.amount.to_f
        employer_esi = payslip.employer_esi.to_f

        row = Row.new(
          employee_code: emp.employee_code,
          name: emp.full_name,
          gross_wages: payslip.gross_pay.to_f.round(0),
          employee_contribution: esi_deduction.round(0),
          employer_contribution: employer_esi.round(0),
          total_contribution: (esi_deduction + employer_esi).round(0),
          ip_number: ""
        )
        @rows << row

        @summary[:total_ee] += esi_deduction
        @summary[:total_er] += employer_esi
        @summary[:total_gross] += payslip.gross_pay.to_f
        @summary[:employee_count] += 1
      end

      self
    end

    def to_csv
      CSV.generate do |csv|
        csv << [ "Employee Code", "Name", "Gross Wages", "Employee Contribution",
                "Employer Contribution", "Total Contribution", "IP Number" ]
        rows.each do |row|
          csv << [ row.employee_code, row.name, row.gross_wages.to_i,
                  row.employee_contribution.to_i, row.employer_contribution.to_i,
                  row.total_contribution.to_i, row.ip_number ]
        end
      end
    end
  end
end
