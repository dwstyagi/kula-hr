require "csv"

module Reports
  class PtChallanReportService
    Row = Struct.new(:employee_code, :name, :gross_pay, :pt_amount, :slab_range,
                     keyword_init: true)

    SlabSummary = Struct.new(:slab_range, :employee_count, :total_pt, keyword_init: true)

    attr_reader :rows, :slab_summaries, :summary

    def initialize(month:, year:)
      @month = month
      @year = year
    end

    def call
      run = PayrollRun.where(status: %w[approved paid]).for_month(@month, @year).first
      @rows = []
      @slab_summaries = []
      @summary = { total_pt: 0, employee_count: 0 }

      return self unless run

      setting = PayrollSetting.first
      return self unless setting&.pt_enabled?

      slabs = ProfessionalTaxSlab.where(state: setting.pt_state).order(:salary_from)

      payslips = Payslip.where(payroll_run: run)
                        .includes(:employee, :line_items)
                        .joins(:employee)
                        .where(employees: { pt_applicable: true })

      slab_map = Hash.new { |h, k| h[k] = { count: 0, total: 0 } }

      payslips.each do |payslip|
        emp = payslip.employee
        pt = payslip.line_items.find_by(component_name: "Professional Tax", component_type: "deduction")&.amount.to_f
        pt = payslip.line_items.find_by(component_name: "PT", component_type: "deduction")&.amount.to_f if pt == 0

        slab = slabs.find { |s| payslip.gross_pay >= s.salary_from && payslip.gross_pay <= s.salary_to }
        slab_range = slab ? "#{slab.salary_from.to_i}-#{slab.salary_to.to_i}" : "N/A"

        row = Row.new(
          employee_code: emp.employee_code,
          name: emp.full_name,
          gross_pay: payslip.gross_pay.to_f.round(0),
          pt_amount: pt.round(0),
          slab_range: slab_range
        )
        @rows << row

        slab_map[slab_range][:count] += 1
        slab_map[slab_range][:total] += pt

        @summary[:total_pt] += pt
        @summary[:employee_count] += 1
      end

      @slab_summaries = slab_map.map do |range, data|
        SlabSummary.new(slab_range: range, employee_count: data[:count], total_pt: data[:total].round(0))
      end

      self
    end

    def to_csv
      CSV.generate do |csv|
        csv << [ "Employee Code", "Name", "Gross Pay", "PT Amount", "Slab Range" ]
        rows.each do |row|
          csv << [ row.employee_code, row.name, row.gross_pay.to_i, row.pt_amount.to_i, row.slab_range ]
        end
        csv << []
        csv << [ "Slab Summary" ]
        csv << [ "Slab Range", "Employees", "Total PT" ]
        slab_summaries.each do |s|
          csv << [ s.slab_range, s.employee_count, s.total_pt.to_i ]
        end
      end
    end
  end
end
