module Payroll
  module BankFileGenerators
    class Hdfc < Base
      # HDFC Corporate Internet Banking — NEFT/RTGS bulk payment file
      # H~<CORP_CODE>~<PRODUCT>~<BATCH_NO>~<TOTAL_AMT>~<DATE>
      # D~<DEBIT_AC>~<BENE_NAME>~<BENE_AC>~<IFSC>~<AMT>~<NARRATION>

      private

      def validate_export!
        super
        @setting = @tenant.payroll_setting
        unless @setting&.hdfc_corporate_code.present? && @setting&.salary_debit_account.present?
          raise BankFileError, "Configure the HDFC corporate code and salary debit account in Payroll Settings before downloading this file."
        end
      end

      def generate
        date  = Date.today.strftime("%d/%m/%Y")
        batch = "BATCH#{@payroll_run.month.to_s.rjust(2, '0')}#{@payroll_run.year}"

        lines = []
        first = true
        emit = lambda do |line|
          if block_given?
            yield((first ? "" : "\r\n") + line)
            first = false
          else
            lines << line
          end
        end
        emit.call("H~#{@setting.hdfc_corporate_code}~NEFT~#{batch}~#{format('%.2f', total_net_pay)}~#{date}")

        @eligible_payslips.each do |payslip|
          emp = payslip.employee
          emit.call([
            "D",
            @setting.salary_debit_account,
            emp.full_name.upcase.gsub(/[~\r\n]/, " ").first(40),
            emp.bank_account_number,
            emp.ifsc_code,
            format("%.2f", payslip.net_pay),
            narration
          ].join("~"))
        end

        lines.join("\r\n")
      end
    end
  end
end
