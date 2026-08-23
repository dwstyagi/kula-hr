module Payroll
  class FullAndFinalPayrollProcessor
    ProcessingResult = Struct.new(:payroll_run, :processed, :skipped, :errors, keyword_init: true)

    def initialize(payroll_run:)
      @run = payroll_run
      @tenant = payroll_run.tenant
      @processed = []
      @skipped = []
      @errors = []
    end

    def call
      raise ArgumentError, "run must be full and final" unless @run.full_and_final?

      @run.start_processing! if @run.may_start_processing?
      return unless @run.processing?

      settlements = @run.full_and_final_settlements.includes(:employee).order(:id)
      raise ArgumentError, "full-and-final settlement is missing" if settlements.empty?

      @run.update!(total_employees: settlements.size)

      ActsAsTenant.with_tenant(@tenant) do
        settlements.each_with_index do |settlement, index|
          process_settlement(settlement)
          @run.update_column(:processed_employees, index + 1)
        end
      end

      finalize
    rescue => e
      @run.update!(notes: [ @run.notes, "Processing failed: #{e.message}" ].compact_blank.join("\n"))
      raise
    end

    private

    # One settlement failing must not abandon the rest of the batch. The run's
    # error list reaches HR by mail, and finalize settles the honest counts.
    def process_settlement(settlement)
      create_payslip(settlement)
      @processed << settlement.employee_id
    rescue => e
      @skipped << settlement.employee_id
      @errors << { employee_id: settlement.employee_id, name: settlement.employee.full_name, error: e.message }
    end

    def create_payslip(settlement)
      ActiveRecord::Base.transaction do
        payslip = @run.payslips.create!(
          tenant: @tenant,
          employee: settlement.employee,
          month: @run.month,
          year: @run.year,
          gross_pay: settlement.total_earnings,
          total_deductions: settlement.total_deductions,
          net_pay: settlement.net_pay,
          employer_pf: 0,
          employer_esi: 0,
          employer_pf_admin: 0,
          employer_edli: 0,
          total_working_days: 0,
          paid_days: 0,
          lop_days: 0
        )

        create_line_items(payslip, settlement)
        settlement.update!(payslip: payslip)
        payslip
      end
    end

    def create_line_items(payslip, settlement)
      sort = 0
      settlement.earning_items.each do |name, amount|
        payslip.line_items.create!(
          component_name: name,
          component_type: "earning",
          amount: amount,
          full_amount: amount,
          sort_order: (sort += 1),
          category: "variable"
        )
      end

      statutory_names = %w[PF ESI TDS] + [ "Professional Tax" ]
      settlement.deduction_items.each do |name, amount|
        payslip.line_items.create!(
          component_name: name,
          component_type: "deduction",
          amount: amount,
          sort_order: (sort += 1),
          category: statutory_names.include?(name) ? "statutory" : "variable"
        )
      end
    end

    def finalize
      @run.update!(
        processed_employees: @processed.size,
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
