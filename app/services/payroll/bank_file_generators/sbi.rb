module Payroll
  module BankFileGenerators
    class Sbi < Base
      # SBI Corporate Multi-Payment (CMP) format — comma-delimited
      # TXN_DATE,BENE_AC_NO,BENE_NAME,BENE_IFSC,AMOUNT,REMARKS

      private

      def generate
        date = Date.today.strftime("%d-%b-%Y").upcase

        lines = []
        lines << "TXN_DATE,BENE_AC_NO,BENE_NAME,BENE_IFSC,AMOUNT,REMARKS"

        @eligible_payslips.each do |payslip|
          emp = payslip.employee
          lines << [
            date,
            emp.bank_account_number,
            emp.full_name.upcase.first(35),
            emp.ifsc_code,
            payslip.net_pay.round(2),
            narration
          ].join(",")
        end

        lines.join("\r\n")
      end
    end
  end
end
