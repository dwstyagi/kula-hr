require "csv"

module Payroll
  module BankFileGenerators
    class GenericCsv < Base
      private

      def generate
        CSV.generate(force_quotes: true) do |csv|
          csv << [ "Sr No", "Employee Code", "Employee Name", "Bank Name",
                   "Account Number", "IFSC Code", "Net Pay", "Narration" ]

          @eligible_payslips.each_with_index do |payslip, i|
            emp = payslip.employee
            csv << [
              i + 1,
              emp.employee_code,
              emp.full_name,
              emp.bank_name.presence || "—",
              emp.bank_account_number,
              emp.ifsc_code,
              payslip.net_pay.round(2),
              "Salary #{@payroll_run.period_label}"
            ]
          end
        end
      end
    end
  end
end
