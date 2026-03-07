require "csv"

module Reports
  class DepartmentBreakdownService
    Row = Struct.new(:department_name, :employee_count, :total_gross, :total_deductions,
                     :total_net, :total_employer_pf, :total_employer_esi, :total_ctc,
                     keyword_init: true)

    attr_reader :rows, :summary

    def initialize(month:, year:)
      @month = month
      @year = year
    end

    def call
      run = PayrollRun.where(status: %w[approved paid]).for_month(@month, @year).first
      @rows = []
      @summary = { total_gross: 0, total_deductions: 0, total_net: 0, total_employer_pf: 0,
                   total_employer_esi: 0, total_ctc: 0, employee_count: 0 }

      return self unless run

      data = Payslip.where(payroll_run: run)
                    .joins(employee: :department)
                    .group("departments.name")
                    .select(
                      "departments.name AS dept_name",
                      "COUNT(*) AS emp_count",
                      "SUM(payslips.gross_pay) AS sum_gross",
                      "SUM(payslips.total_deductions) AS sum_deductions",
                      "SUM(payslips.net_pay) AS sum_net",
                      "SUM(payslips.employer_pf) AS sum_employer_pf",
                      "SUM(payslips.employer_esi) AS sum_employer_esi"
                    )

      data.each do |d|
        ctc = d.sum_gross.to_f + d.sum_employer_pf.to_f + d.sum_employer_esi.to_f
        row = Row.new(
          department_name: d.dept_name,
          employee_count: d.emp_count.to_i,
          total_gross: d.sum_gross.to_f,
          total_deductions: d.sum_deductions.to_f,
          total_net: d.sum_net.to_f,
          total_employer_pf: d.sum_employer_pf.to_f,
          total_employer_esi: d.sum_employer_esi.to_f,
          total_ctc: ctc
        )
        @rows << row
        @summary[:total_gross] += row.total_gross
        @summary[:total_deductions] += row.total_deductions
        @summary[:total_net] += row.total_net
        @summary[:total_employer_pf] += row.total_employer_pf
        @summary[:total_employer_esi] += row.total_employer_esi
        @summary[:total_ctc] += ctc
        @summary[:employee_count] += row.employee_count
      end

      self
    end

    def to_csv
      CSV.generate do |csv|
        csv << [ "Department", "Employees", "Gross Pay", "Deductions", "Net Pay",
                "Employer PF", "Employer ESI", "CTC" ]
        rows.each do |row|
          csv << [ row.department_name, row.employee_count, row.total_gross.round(2),
                  row.total_deductions.round(2), row.total_net.round(2),
                  row.total_employer_pf.round(2), row.total_employer_esi.round(2),
                  row.total_ctc.round(2) ]
        end
        csv << [ "Total", @summary[:employee_count], @summary[:total_gross].round(2),
                @summary[:total_deductions].round(2), @summary[:total_net].round(2),
                @summary[:total_employer_pf].round(2), @summary[:total_employer_esi].round(2),
                @summary[:total_ctc].round(2) ]
      end
    end
  end
end
