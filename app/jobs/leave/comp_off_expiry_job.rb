module Leave
  # Runs daily. Finds approved comp-off requests past their expiry date
  # and deducts the unused day from the employee's balance.
  class CompOffExpiryJob < ApplicationJob
    queue_as :scheduled

    def perform
      Tenant.where(status: %w[trial active]).find_each do |tenant|
        ActsAsTenant.with_tenant(tenant) do
          expire_for_tenant(tenant)
        end
      rescue StandardError => e
        Rails.logger.error("[CompOffExpiry] Failed for tenant #{tenant.id}: #{e.message}")
      end
    end

    private

    def expire_for_tenant(tenant)
      comp_off_type = LeaveType.find_by(code: "CO")
      return unless comp_off_type

      fy = LeaveBalance.current_financial_year

      CompOffRequest
        .where(status: :approved, balance_expired: false)
        .where("expiry_date < ?", Date.today)
        .includes(:employee)
        .find_each do |request|
          balance = LeaveBalance.find_by(
            employee:       request.employee,
            leave_type:     comp_off_type,
            financial_year: fy
          )
          next unless balance

          balance.with_lock do
            days_to_expire = [ balance.remaining_days, 1 ].min
            if days_to_expire > 0
              balance.update!(
                remaining_days: balance.remaining_days - days_to_expire,
                total_days:     balance.total_days - days_to_expire
              )
            end
          end

          request.update!(balance_expired: true)
        end
    end
  end
end
