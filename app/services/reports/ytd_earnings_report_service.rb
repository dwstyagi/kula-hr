require "csv"

module Reports
  class YtdEarningsReportService
    Row = Struct.new(:employee_code, :name, :department, :months_count,
                     :total_gross, :total_deductions, :total_net,
                     :component_totals, keyword_init: true)

    attr_reader :rows, :summary, :component_names

    def initialize(financial_year:)
      @financial_year = financial_year
      parts = financial_year.split("-")
      start_year = parts[0].to_i
      @fy_start_month = 4
      @fy_start_year = start_year
      @fy_end_month = 3
      @fy_end_year = start_year + 1
    end

    def call
      @rows = []
      @component_names = Set.new
      @summary = { total_gross: 0, total_deductions: 0, total_net: 0, employee_count: 0 }

      approved_runs = PayrollRun.where(status: %w[approved paid])
                                .where(fy_condition)

      return self if approved_runs.empty?

      payslips = Payslip.where(payroll_run: approved_runs)
                        .includes(:employee, :line_items, employee: :department)

      grouped = payslips.group_by(&:employee_id)

      grouped.each do |_emp_id, emp_payslips|
        emp = emp_payslips.first.employee
        next unless emp

        component_totals = {}
        emp_payslips.each do |ps|
          ps.line_items.each do |li|
            key = "#{li.component_type}:#{li.component_name}"
            @component_names << key
            component_totals[key] = (component_totals[key] || 0) + li.amount.to_f
          end
        end

        total_gross = emp_payslips.sum { |p| p.gross_pay.to_f }
        total_ded = emp_payslips.sum { |p| p.total_deductions.to_f }
        total_net = emp_payslips.sum { |p| p.net_pay.to_f }

        row = Row.new(
          employee_code: emp.employee_code,
          name: emp.full_name,
          department: emp.department&.name || "N/A",
          months_count: emp_payslips.size,
          total_gross: total_gross.round(0),
          total_deductions: total_ded.round(0),
          total_net: total_net.round(0),
          component_totals: component_totals
        )
        @rows << row

        @summary[:total_gross] += total_gross
        @summary[:total_deductions] += total_ded
        @summary[:total_net] += total_net
        @summary[:employee_count] += 1
      end

      @component_names = @component_names.sort
      self
    end

    def to_csv
      headers = [ "Employee Code", "Name", "Department", "Months" ]
      earning_names = component_names.select { |c| c.start_with?("earning:") }.map { |c| c.sub("earning:", "") }
      deduction_names = component_names.select { |c| c.start_with?("deduction:") }.map { |c| c.sub("deduction:", "") }
      headers += earning_names
      headers += [ "Total Gross" ]
      headers += deduction_names
      headers += [ "Total Deductions", "Net Pay" ]

      CSV.generate do |csv|
        csv << headers
        rows.each do |row|
          line = [ row.employee_code, row.name, row.department, row.months_count ]
          earning_names.each { |n| line << (row.component_totals["earning:#{n}"] || 0).round(0) }
          line << row.total_gross
          deduction_names.each { |n| line << (row.component_totals["deduction:#{n}"] || 0).round(0) }
          line += [ row.total_deductions, row.total_net ]
          csv << line
        end
      end
    end

    private

    def fy_condition
      # April of start_year to March of end_year
      "(payroll_runs.year = #{@fy_start_year} AND payroll_runs.month >= #{@fy_start_month}) OR " \
      "(payroll_runs.year = #{@fy_end_year} AND payroll_runs.month <= #{@fy_end_month})"
    end
  end
end
