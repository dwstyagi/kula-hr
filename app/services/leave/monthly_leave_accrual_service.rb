module Leave
  class MonthlyLeaveAccrualService
    WORKING_STATUSES = %w[active probation].freeze

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
          # April is seeded by rollover; the joining allocation seeds new hires.
          unless @period.month == 4
            year = @period.month >= 4 ? @period.year : @period.year - 1
            fy = "#{year}-#{(year + 1).to_s.last(2)}"
            employees = Employee.where(employment_status: WORKING_STATUSES).where("joining_date < ?", @period).select(:id)
            LeaveType.active.paid.find_each do |type|
              quota = (type.annual_quota / 12.0).round(2)
              LeaveBalance.where(financial_year: fy, leave_type_id: type.id, employee_id: employees)
                .update_all([ "total_days = total_days + ?, remaining_days = remaining_days + ?, updated_at = ?", quota, quota, Time.current ])
            end
          end
        end
      end
    rescue ActiveRecord::RecordNotUnique
      # The unique period marker commits atomically with the credit.
      nil
    end
  end
end
