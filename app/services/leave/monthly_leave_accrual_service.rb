module Leave
  class MonthlyLeaveAccrualService
    WORKING_STATUSES = Employee::IN_SERVICE_STATUSES

    def self.run_for_all_tenants(period: Date.current.beginning_of_month)
      Tenant.where(status: %w[trial active]).find_each do |tenant|
        new(tenant: tenant, period: period).call
      end
    end

    def initialize(tenant:, period: Date.current.beginning_of_month)
      @tenant, @period = tenant, period.to_date.beginning_of_month
    end

    def call
      ActsAsTenant.with_tenant(@tenant) do
        LeaveAccrual.transaction(requires_new: true) do
          LeaveAccrual.create!(tenant: @tenant, period: @period)
          next if @period.month == 4 # April is seeded by rollover.

          employees = Employee.where(employment_status: WORKING_STATUSES).where("joining_date < ?", @period)
          LeaveAuditContext.set(kind: "accrual", reason: "Monthly accrual for #{@period.strftime('%B %Y')}") do
            LeaveType.active.paid.find_each do |type|
              quota = AccrualAmount.for(type, @period)
              employees.find_each do |employee|
                balance = LeaveBalance.find_or_create_by!(employee: employee, leave_type: type,
                  financial_year: FinancialYear.label(@period)) { |row| row.tenant = @tenant }
                balance.with_lock do
                  balance.update!(total_days: balance.total_days + quota, remaining_days: balance.remaining_days + quota)
                end
              end
            end
          end
        end
      end
    rescue ActiveRecord::RecordNotUnique
      nil # Unique period marker and credits commit atomically.
    end
  end
end
