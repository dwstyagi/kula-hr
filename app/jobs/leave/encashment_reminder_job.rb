module Leave
  # Runs on March 1st at 9am. Notifies every active/probation employee
  # who has carry-forward eligible days — email + in-app notification.
  class EncashmentReminderJob < ApplicationJob
    queue_as :mailers

    def perform
      Tenant.where(status: %w[trial active]).find_each do |tenant|
        ActsAsTenant.with_tenant(tenant) do
          notify_eligible_employees(tenant)
        end
      rescue StandardError => e
        Rails.logger.error("[EncashmentReminder] Failed for tenant #{tenant.id}: #{e.message}")
      end
    end

    private

    def notify_eligible_employees(tenant)
      fy          = LeaveBalance.current_financial_year
      leave_types = LeaveType.active.paid.where(carry_forward: true).to_a
      return if leave_types.empty?

      employees = Employee.where(employment_status: %w[active probation])
      return if employees.empty?

      employees.each do |employee|
        next unless employee.user

        leave_types.each do |leave_type|
          balance = LeaveBalance.find_by(
            employee: employee,
            leave_type: leave_type,
            financial_year: fy
          )
          next unless balance

          eligible_days = [ leave_type.max_carry_forward, balance.remaining_days ].min
          next unless eligible_days > 0

          already_requested = LeaveEncashmentRequest.exists?(
            employee: employee,
            leave_type: leave_type,
            financial_year: fy
          )
          next if already_requested

          LeaveMailer.encashment_reminder(employee, leave_type, eligible_days).deliver_later
          broadcast_reminder(employee, leave_type, eligible_days)
        end
      end
    end

    def broadcast_reminder(employee, leave_type, eligible_days)
      ActionCable.server.broadcast(
        "notifications_user_#{employee.user.id}",
        {
          title:   "Year-End Leave Reminder",
          message: "You have #{eligible_days.to_i} #{leave_type.name} day(s) eligible for encashment. Submit a request before March 31st, or they carry forward automatically.",
          kind:    "info",
          url:     "/portal/leave_requests"
        }
      )
    end
  end
end
