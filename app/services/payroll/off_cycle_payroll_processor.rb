module Payroll
  class OffCyclePayrollProcessor
    ProcessingResult = Struct.new(:payroll_run, :processed, :skipped, :errors, keyword_init: true)

    def initialize(payroll_run:)
      @run = payroll_run
      @tenant = payroll_run.tenant
      @processed = []
      @skipped = []
      @errors = []
    end

    def call
      raise ArgumentError, "regular payroll requires PayrollProcessor" if @run.regular?

      @run.start_processing! if @run.may_start_processing?
      return unless @run.processing?

      entries = @run.off_cycle_payroll_entries.includes(:employee).order(:id)
      @run.update!(total_employees: entries.size)

      ActsAsTenant.with_tenant(@tenant) do
        entries.each_with_index do |entry, index|
          process_entry(entry)
          @run.update_column(:processed_employees, index + 1)
        end
      end

      finalize
    rescue => e
      @run.update!(notes: [ @run.notes, "Processing failed: #{e.message}" ].compact_blank.join("\n"))
      raise
    end

    private

    def process_entry(entry)
      ActiveRecord::Base.transaction do
        payslip = @run.payslips.create!(
          tenant: @tenant,
          employee: entry.employee,
          month: @run.month,
          year: @run.year,
          gross_pay: entry.gross_amount,
          total_deductions: entry.tds_amount,
          net_pay: entry.net_amount,
          employer_pf: 0,
          employer_esi: 0,
          employer_pf_admin: 0,
          employer_edli: 0,
          total_working_days: 0,
          paid_days: 0,
          lop_days: 0
        )

        payslip.line_items.create!(
          component_name: @run.title,
          component_type: "earning",
          amount: entry.gross_amount,
          full_amount: entry.gross_amount,
          sort_order: 1,
          category: "variable"
        )

        if entry.tds_amount.positive?
          payslip.line_items.create!(
            component_name: "TDS",
            component_type: "deduction",
            amount: entry.tds_amount,
            sort_order: 2,
            category: "statutory"
          )
        end
      end

      @processed << entry.employee_id
    rescue => e
      @skipped << entry.employee_id
      @errors << { employee_id: entry.employee_id, name: entry.employee.full_name, error: e.message }
    end

    def finalize
      @run.update!(
        total_gross: @run.payslips.sum(:gross_pay),
        total_deductions: @run.payslips.sum(:total_deductions),
        total_net_pay: @run.payslips.sum(:net_pay),
        total_employer_cost: 0
      )
      @run.finish_processing!

      ProcessingResult.new(
        payroll_run: @run,
        processed: @processed,
        skipped: @skipped,
        errors: @errors
      )
    end
  end
end
