module Leave
  class PeriodGuard
    def initialize(request)
      @request = request
    end

    def check!
      @request.from_date.beginning_of_month.upto(@request.to_date).select { |date| date.day == 1 }.each do |period|
        locked = AttendanceSummary.where(employee_id: @request.employee_id, month: period.month, year: period.year).locked.exists?
        payroll = PayrollRun.for_month(period.month, period.year).first
        if locked || (payroll && (!payroll.draft? || payroll.payslips.exists?))
          raise RequestTransition::Error, "Leave cannot change for #{period.strftime('%B %Y')}: attendance is locked or payroll has been calculated. HR must reopen the period through the payroll correction process first."
        end
      end
      @request.days_by_financial_year.each_key do |year|
        next_year = FinancialYear.label_for_start_year(year.first(4).to_i + 1)
        if LeaveBalance.exists?(employee: @request.employee, leave_type: @request.leave_type, financial_year: next_year)
          raise RequestTransition::Error, "Leave cannot change in #{year}: its balance has already rolled into #{next_year}."
        end
      end
    end
  end
end
