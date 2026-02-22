module Leave
  # Broadcasts real-time notifications over Action Cable when leave request
  # status changes. Each user receives messages on their private stream:
  #   "notifications_user_#{user.id}"
  class NotificationBroadcaster
    def initialize(leave_request:)
      @leave_request = leave_request
      @employee      = leave_request.employee
      @leave_type    = leave_request.leave_type
    end

    # Called when employee submits a new request.
    # Notifies: all HR/admin users in the tenant + reporting manager.
    def broadcast_new_request!
      message = "#{@employee.full_name} applied for " \
                "#{@leave_request.number_of_days.to_i} day(s) of #{@leave_type.name}"

      recipients_for_new_request.each do |user|
        broadcast_to(user, {
          title:   "New Leave Request",
          message: message,
          kind:    "info",
          url:     "/admin/leave_requests"
        })
      end
    end

    # Called when HR approves or rejects.
    # Notifies: the employee themselves.
    def broadcast_status_update!
      return unless @employee.user

      status  = @leave_request.status
      title   = "Leave #{status.titleize}"
      message = "Your #{@leave_type.name} request " \
                "(#{@leave_request.number_of_days.to_i} day(s)) has been #{status}."
      message += " Reason: #{@leave_request.rejection_reason}" if @leave_request.rejected? && @leave_request.rejection_reason.present?

      broadcast_to(@employee.user, {
        title:   title,
        message: message,
        kind:    status == "approved" ? "success" : "error",
        url:     "/portal/leave_requests"
      })
    end

    private

    def recipients_for_new_request
      users = hr_and_admin_users

      # Also notify reporting manager if they have a user account
      if (manager = @employee.reporting_manager&.user)
        users |= [ manager ]
      end

      users
    end

    def hr_and_admin_users
      tenant = @employee.tenant
      TenantUser
        .where(tenant: tenant)
        .joins(user: :roles)
        .where(roles: { name: %w[super_admin hr_admin] })
        .includes(:user)
        .map(&:user)
        .uniq
    end

    def broadcast_to(user, payload)
      ActionCable.server.broadcast("notifications_user_#{user.id}", payload)
    end
  end
end
