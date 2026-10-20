module Leave
  class RequestTransition
    Error = Class.new(StandardError)

    def initialize(leave_request:, actor:)
      @request, @actor = leave_request, actor
    end

    def call(action, reason: nil)
      raise Error, "The review reason must be at most 1,000 characters." if reason.to_s.length > 1000

      @request.tenant.with_lock do
        @request.with_lock do
          LeaveAuditContext.set(actor: @actor, reason: "Leave request ##{@request.id}: #{action}. #{reason}".strip) do
            case action.to_sym
            when :approve
              pending!
              PeriodGuard.new(@request).check!
              raise Error, "This request no longer contains working days." if @request.daily_units.empty?
              @request.update!(number_of_days: @request.daily_units.values.sum)
              check_overlap!
              LeaveBalanceAdjuster.new(leave_request: @request).debit!
              @request.update!(status: :approved, approved_by: @actor, approved_at: Time.current)
              refresh_attendance!
            when :reject
              pending!
              @request.update!(status: :rejected, rejection_reason: reason.to_s.strip,
                approved_by: @actor, approved_at: Time.current)
            when :cancel
              raise Error, "Only pending or approved requests can be cancelled." unless @request.pending? || @request.approved?
              was_approved = @request.approved?
              if was_approved
                PeriodGuard.new(@request).check!
                LeaveBalanceAdjuster.new(leave_request: @request).credit!
              end
              @request.update!(status: :cancelled, cancellation_requested_at: nil)
              refresh_attendance! if was_approved
            when :request_cancellation
              raise Error, "Only approved leave can be submitted for cancellation." unless @request.approved?
              raise Error, "A cancellation request is already awaiting HR review." if @request.cancellation_pending?
              raise Error, "Please explain why the approved leave should be cancelled." if reason.blank?
              PeriodGuard.new(@request).check!
              @request.update!(cancellation_requested_at: Time.current, cancellation_reason: reason.to_s.strip)
            when :reject_cancellation
              raise Error, "No cancellation request is awaiting review." unless @request.cancellation_pending?
              raise Error, "Please explain why the cancellation was rejected." if reason.blank?
              @request.update!(cancellation_requested_at: nil)
            else
              raise ArgumentError, "Unknown leave action"
            end
          end
        end
      end
      @request
    end

    private

    def pending!
      raise Error, "Only pending requests can be reviewed." unless @request.pending?
    end

    def check_overlap!
      others = LeaveRequest.approved.where(employee_id: @request.employee_id).where.not(id: @request.id)
        .where("from_date <= ? AND to_date >= ?", @request.to_date, @request.from_date)
      others = others.where(duration: [ "full_day", @request.duration ]) if @request.half_day?
      raise Error, "This request overlaps another approved leave." if others.exists?
    end

    def refresh_attendance!
      @request.from_date.beginning_of_month.upto(@request.to_date).select { |date| date.day == 1 }.each do |period|
        next unless AttendanceSummary.exists?(employee_id: @request.employee_id, month: period.month, year: period.year)

        Attendance::SummaryGenerator.new(month: period.month, year: period.year,
          tenant: @request.tenant, employee_ids: [ @request.employee_id ]).call
      end
    end
  end
end
