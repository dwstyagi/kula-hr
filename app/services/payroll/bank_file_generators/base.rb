module Payroll
  module BankFileGenerators
    class BankFileError < StandardError; end

    class Base
      attr_reader :missing_bank_details

      def initialize(payroll_run:)
        @payroll_run = payroll_run
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
        @missing_bank_details ||= @payslips
          .select { |p| p.employee.bank_account_number.blank? || p.employee.ifsc_code.blank? }
          .map(&:employee)
      end

      private

      # Filters out employees with missing bank details (they are warned on screen, not hard-errored)
      def detect_missing!
        @missing_bank_details = employees_missing_bank_details
        @eligible_payslips    = @payslips.reject { |p| p.employee.bank_account_number.blank? || p.employee.ifsc_code.blank? }
      end

      def generate
        raise NotImplementedError, "#{self.class} must implement #generate"
      end

      def narration
        "SAL-#{@payroll_run.month_name[0..2].upcase}-#{@payroll_run.year}"
      end

      def total_net_pay
        @eligible_payslips.sum(&:net_pay)
      end
    end
  end
end
