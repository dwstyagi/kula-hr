module Attendance
  # Single source of truth for "which attendance month may HR work on right now?".
  #
  # Past months are always open. The CURRENT month opens only for its final
  # week, so HR can lock attendance and start payroll on the last few days of
  # the month. Opening it any earlier would let HR freeze assumed data —
  # SummaryGenerator fills days_present for the *whole* month regardless of
  # today's date — and only a super admin can unlock it again.
  #
  # Consumed by:
  #   - Admin::AttendanceSummariesController → generate/lock gate + default month
  #   - Admin::DashboardController           → setup checklist + needs-attention
  #   - PayrollRun.next_unprocessed_period   → default period on the new-run form
  #
  # Keeping the rule here guarantees the gate, the dashboard prompts and the
  # payroll defaults can never disagree about which month is in play.
  class MonthWindow
    # How many trailing days of the current month are open, inclusive of the
    # last day. 7 → opens on the 25th of a 31-day month, the 22nd of February.
    FINAL_WINDOW_DAYS = 7

    class << self
      # May attendance for this month/year be generated, edited or locked?
      def open?(month, year, today: Date.current)
        Date.new(year, month, 1) <= latest_open(today: today)
      end

      # Newest month HR may work on right now, as a Date on the 1st.
      def latest_open(today: Date.current)
        (current_month_open?(today: today) ? today : today.prev_month).beginning_of_month
      end

      # Has the current month reached its final window?
      def current_month_open?(today: Date.current)
        today >= opens_on(today: today)
      end

      # First day on which today's own month becomes available.
      def opens_on(today: Date.current)
        today.end_of_month - (FINAL_WINDOW_DAYS - 1)
      end
    end
  end
end
