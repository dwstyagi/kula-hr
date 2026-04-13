module Leave
  # Credits one month's leave quota to every active or probation employee on the 1st of each month.
  # Called by MonthlyLeaveAccrualJob via sidekiq-cron.
  #
  # Monthly quota = annual_quota / 12.0 (rounded to 2 decimal places).
  # Employees who joined mid-month still receive the full monthly quota (no pro-rating).
  # Only employees with an existing balance record for the current FY are accrued
  # (i.e. employees who joined before this month and had their joining allocation created).
  class MonthlyLeaveAccrualService
    WORKING_STATUSES = %w[active probation].freeze

    def self.run_for_all_tenants
      Tenant.where(status: %w[trial active]).find_each do |tenant|
        ActsAsTenant.with_tenant(tenant) do
          new(tenant: tenant).call
        end
      rescue StandardError => e
        Rails.logger.error("[MonthlyLeaveAccrual] Failed for tenant #{tenant.id} (#{tenant.subdomain}): #{e.message}")
      end
    end

    def initialize(tenant:)
      @tenant = tenant
    end

    def call
      leave_types = LeaveType.active.paid.to_a
      return if leave_types.empty?

      # Resolve working employee IDs first to avoid JOIN ambiguity in update_all
      working_ids = Employee.where(employment_status: WORKING_STATUSES).ids
      return if working_ids.empty?

      leave_types.each do |leave_type|
        monthly_quota = (leave_type.annual_quota / 12.0).round(2)

        LeaveBalance.current
                    .where(leave_type_id: leave_type.id, employee_id: working_ids)
                    .update_all(
                      "total_days = total_days + #{monthly_quota}, " \
                      "remaining_days = remaining_days + #{monthly_quota}, " \
                      "updated_at = NOW()"
                    )
      end
    end
  end
end
