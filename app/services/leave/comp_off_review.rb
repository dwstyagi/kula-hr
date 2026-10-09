module Leave
  # Approves or rejects a comp-off request. Shared by HR (admin) and the
  # employee's reporting manager (portal). The status change and the balance
  # credit commit together, under a row lock, so a double click or two
  # reviewers cannot credit the same request twice.
  class CompOffReview
    def initialize(request:, reviewer:)
      @request  = request
      @reviewer = reviewer
    end

    # Returns false when the request is no longer pending.
    def approve!
      decided = @request.with_lock do
        next false unless @request.pending?

        @request.update!(status: :approved, approved_by: @reviewer, approved_at: Time.current)
        CompOffCreditService.new(comp_off_request: @request).call
        true
      end
      notify(:approved) if decided
      decided
    end

    def reject!(reason:)
      decided = @request.with_lock do
        next false unless @request.pending?

        @request.update!(status: :rejected, rejection_reason: reason.to_s.strip,
                         approved_by: @reviewer, approved_at: Time.current)
        true
      end
      notify(:rejected) if decided
      decided
    end

    private

    def notify(outcome)
      user = @request.employee.user
      return unless user

      worked = @request.worked_date.strftime("%d %b %Y")
      payload = if outcome == :approved
        { title: "Comp-Off Approved",
          message: "Your comp-off for #{worked} was approved. 1 day credited — use it before #{@request.expiry_date.strftime('%d %b %Y')}.",
          kind: "success" }
      else
        reason = @request.rejection_reason.present? ? " Reason: #{@request.rejection_reason}" : ""
        { title: "Comp-Off Not Approved",
          message: "Your comp-off request for #{worked} was not approved.#{reason}",
          kind: "error" }
      end
      ActionCable.server.broadcast("notifications_user_#{user.id}", payload.merge(url: "/portal/comp_off_requests"))
    end
  end
end
