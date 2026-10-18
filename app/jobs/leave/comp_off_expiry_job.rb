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

      CompOffRequest
        .where(status: :approved, balance_expired: false)
        .where("expiry_date < ?", Date.current)
        .includes(:employee)
        .find_each do |request|
          balance = LeaveBalance.find_by(
            employee:       request.employee,
            leave_type:     comp_off_type,
            financial_year: FinancialYear.label((request.approved_at || request.created_at).to_date)
          )
          next unless balance

          balance.with_lock do
            request.with_lock do
              next if request.balance_expired?

              days_to_expire = [ balance.remaining_days, request.remaining_days ].min
              if days_to_expire > 0
                balance.update!(remaining_days: balance.remaining_days - days_to_expire,
                  total_days: balance.total_days - days_to_expire)
              end
              request.update!(balance_expired: true, remaining_days: 0)
            end
          end
        end
    end
  end
end
