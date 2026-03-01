module Payroll
  module BankFileGenerators
    class Icici < Base
      # ICICI Corporate Internet Banking — pipe-delimited bulk salary file
      # PAYMENT_DATE|BENE_AC|BENE_NAME|BENE_BANK_IFSC|AMOUNT|PAYMENT_TYPE|REMARKS

      private

      def generate
        date = Date.today.strftime("%d/%m/%Y")

        lines = []
        lines << "PAYMENT_DATE|BENE_ACCOUNT_NUMBER|BENE_NAME|BENE_BANK_IFSC|AMOUNT|PAYMENT_TYPE|REMARKS"

        @eligible_payslips.each do |payslip|
          emp = payslip.employee
          lines << [
            date,
            emp.bank_account_number,
            emp.full_name.upcase.first(50),
            emp.ifsc_code,
            format("%.2f", payslip.net_pay),
            "NEFT",
            narration
          ].join("|")
        end

        lines.join("\r\n")
      end
    end
  end
end
