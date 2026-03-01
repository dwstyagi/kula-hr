module Payroll
  module BankFileGenerators
    class Hdfc < Base
      # HDFC Corporate Internet Banking — NEFT/RTGS bulk payment file
      # H~<CORP_CODE>~<PRODUCT>~<BATCH_NO>~<TOTAL_AMT>~<DATE>
      # D~<DEBIT_AC>~<BENE_NAME>~<BENE_AC>~<IFSC>~<AMT>~<NARRATION>

      private

      def generate
        date  = Date.today.strftime("%d/%m/%Y")
        batch = "BATCH#{@payroll_run.month.to_s.rjust(2, '0')}#{@payroll_run.year}"

        lines = []
        lines << "H~CORP001~NEFT~#{batch}~#{total_net_pay.to_i}~#{date}"

        @eligible_payslips.each do |payslip|
          emp = payslip.employee
          lines << [
            "D",
            "DEBIT_ACCOUNT",                     # company debit account (configure per tenant)
            emp.full_name.upcase.first(40),       # beneficiary name (HDFC max 40 chars)
            emp.bank_account_number,
            emp.ifsc_code,
            payslip.net_pay.to_i,
            narration
          ].join("~")
        end

        lines.join("\r\n")
      end
    end
  end
end
