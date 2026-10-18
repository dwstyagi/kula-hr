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
          # April is seeded by rollover; the joining allocation seeds new hires.
          unless @period.month == 4
            fy = FinancialYear.label(@period)
            employees = Employee.where(employment_status: WORKING_STATUSES).where("joining_date < ?", @period).select(:id)
            LeaveType.active.paid.find_each do |type|
              quota = (type.annual_quota / 12.0).round(2)
              now = Time.current
              employees.in_batches(of: 100) do |batch|
                rows = batch.pluck(:id).map do |id|
                  { tenant_id: @tenant.id, employee_id: id, leave_type_id: type.id,
                    financial_year: fy, total_days: 0, remaining_days: 0, used_days: 0,
                    carried_forward_days: 0, created_at: now, updated_at: now }
                end
                LeaveBalance.insert_all(rows, unique_by: %i[employee_id leave_type_id financial_year]) if rows.any?
              end
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
