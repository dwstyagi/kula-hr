module Payroll
  module BankFileGenerators
    class BankFileError < StandardError; end

    class Base
      attr_reader :missing_bank_details

      def initialize(payroll_run:)
        @payroll_run = payroll_run
        @tenant = payroll_run.tenant
        @payslips    = payroll_run.payslips
                                  .includes(:employee)
                                  .where("net_pay > 0")
                                  .order("employees.last_name, employees.first_name")
      end

      def call
        detect_missing!
        generate
      end

      # Returns employees missing bank details (non-raising check for UI warnings)
      def employees_missing_bank_details
        @missing_bank_details ||= Employee.where(id: missing_scope.select(:employee_id)).order(:id).limit(50).to_a
      end

      def stream
        Enumerator.new do |out|
          ActsAsTenant.with_tenant(@tenant) do
            detect_missing!
            generate { |line| out << line }
          end
        end
      end

      private

      # Filters out employees with missing bank details (they are warned on screen, not hard-errored)
      def detect_missing!
        @missing_bank_details = employees_missing_bank_details
        @eligible_scope = @payslips.where.not(id: missing_scope.select(:id))
        @eligible_payslips = @eligible_scope.reorder(:id).find_each(batch_size: 100)
      end

      def missing_scope
        @payslips.joins(:employee).where("NULLIF(TRIM(employees.bank_account_number), '') IS NULL OR NULLIF(TRIM(employees.ifsc_code), '') IS NULL")
      end

      def generate
        raise NotImplementedError, "#{self.class} must implement #generate"
      end

      def narration
        return "OFFCYCLE-#{@payroll_run.id}" if @payroll_run.off_cycle?

        "SAL-#{@payroll_run.month_name[0..2].upcase}-#{@payroll_run.year}"
      end

      def total_net_pay
        @eligible_scope.sum(:net_pay)
      end
    end
  end
end
