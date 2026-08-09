module Payroll
  class FullAndFinalPayrollProcessor
    ProcessingResult = Struct.new(:payroll_run, :processed, :skipped, :errors, keyword_init: true)

    def initialize(payroll_run:)
      @run = payroll_run
      @tenant = payroll_run.tenant
    end

    def call
      raise ArgumentError, "run must be full and final" unless @run.full_and_final?

      @run.start_processing! if @run.may_start_processing?
      return unless @run.processing?

      settlement = @run.full_and_final_settlement
      raise ArgumentError, "full-and-final settlement is missing" unless settlement

      @run.update!(total_employees: 1)
      payslip = ActsAsTenant.with_tenant(@tenant) { create_payslip(settlement) }

      @run.update!(
        processed_employees: 1,
        total_gross: payslip.gross_pay,
        total_deductions: payslip.total_deductions,
        total_net_pay: payslip.net_pay,
        total_employer_cost: 0
      )
      @run.finish_processing!

      ProcessingResult.new(
        payroll_run: @run,
        processed: [ settlement.employee_id ],
        skipped: [],
        errors: []
      )
    rescue => e
      @run.update!(notes: [ @run.notes, "Processing failed: #{e.message}" ].compact_blank.join("\n"))
      raise
    end

    private

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
  end
end
