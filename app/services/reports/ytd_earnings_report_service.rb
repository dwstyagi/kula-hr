require "csv"

module Reports
  class YtdEarningsReportService
    Row = Struct.new(:employee_code, :name, :department, :months_count,
                     :total_gross, :total_deductions, :total_net,
                     :component_totals, keyword_init: true)
    attr_reader :rows, :summary, :component_names

    def initialize(financial_year:, employees: nil)
      @financial_year, @employees = financial_year, employees
      @tenant = ActsAsTenant.current_tenant
      @start_year = financial_year.split("-").first.to_i
    end

    def employee_scope
      Employee.where(id: payslips.select(:employee_id)).order(:id)
    end

    def call
      gross, deductions, net, count = payslips.pick(
        Arel.sql("COALESCE(SUM(gross_pay), 0)"), Arel.sql("COALESCE(SUM(total_deductions), 0)"),
        Arel.sql("COALESCE(SUM(net_pay), 0)"), Arel.sql("COUNT(DISTINCT employee_id)"))
      @summary = { total_gross: gross, total_deductions: deductions, total_net: net, employee_count: count }
      load_component_names
      @rows = rows_for(@employees || employee_scope)
      self
    end

    def to_csv
      CSV.generate do |csv|
        csv << csv_headers
        rows.each { |row| csv << csv_row(row) }
      end
    end

    # Rack consumes this after the controller returns, so restore tenant context
    # inside enumeration and keep allocations bounded independently of history.
    def csv_stream
      Enumerator.new do |output|
        ActsAsTenant.with_tenant(@tenant) do
          load_component_names
          output << CSV.generate_line(csv_headers)
          employee_scope.find_in_batches(batch_size: 100) do |employees|
            rows_for(employees).each { |row| output << CSV.generate_line(csv_row(row)) }
          end
        end
      end
    end

    private

    def payslips
      runs = PayrollRun.where(status: %w[approved paid]).where(
        "(year = :first AND month >= 4) OR (year = :last AND month <= 3)", first: @start_year, last: @start_year + 1)
      Payslip.where(payroll_run_id: runs.select(:id))
    end

    def load_component_names
      @component_names = PayslipLineItem.where(payslip_id: payslips.select(:id))
        .distinct.pluck(:component_type, :component_name).map { |type, name| "#{type}:#{name}" }.sort
    end

    def rows_for(employees)
      employees = employees.to_a
      return [] if employees.empty?
      ActiveRecord::Associations::Preloader.new(records: employees, associations: :department).call
      selected = payslips.where(employee_id: employees.map(&:id))
      # Aggregate headlines separately from components to avoid join fan-out.
      totals = selected.group(:employee_id).pluck(:employee_id, Arel.sql("COUNT(*)"),
        Arel.sql("SUM(gross_pay)"), Arel.sql("SUM(total_deductions)"), Arel.sql("SUM(net_pay)"))
        .index_by(&:first)
      components = Hash.new { |h, k| h[k] = {} }
      PayslipLineItem.joins(:payslip).where(payslip_id: selected.select(:id))
        .group("payslips.employee_id", :component_type, :component_name).sum(:amount)
        .each { |(id, type, name), amount| components[id]["#{type}:#{name}"] = amount }
      employees.filter_map do |employee|
        total = totals[employee.id]
        next unless total
        _, count, gross, deductions, net = total
        Row.new(employee_code: employee.employee_code, name: employee.full_name,
          department: employee.department&.name || "N/A", months_count: count,
          total_gross: gross.round(0), total_deductions: deductions.round(0), total_net: net.round(0),
          component_totals: components[employee.id])
      end
    end

    def earning_names = component_names.grep(/^earning:/)
    def deduction_names = component_names.grep(/^deduction:/)

    def csv_headers
      [ "Employee Code", "Name", "Department", "Months" ] + earning_names.map { |s| s.delete_prefix("earning:") } +
        [ "Total Gross" ] + deduction_names.map { |s| s.delete_prefix("deduction:") } + [ "Total Deductions", "Net Pay" ]
    end

    def csv_row(row)
      [ row.employee_code, row.name, row.department, row.months_count ] +
        earning_names.map { |key| (row.component_totals[key] || 0).round(0) } + [ row.total_gross ] +
        deduction_names.map { |key| (row.component_totals[key] || 0).round(0) } + [ row.total_deductions, row.total_net ]
    end
  end
end
