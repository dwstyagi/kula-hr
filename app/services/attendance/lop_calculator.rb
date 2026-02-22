module Attendance
  # Computes LOP days and the corresponding salary proration factor for payroll.
  # Used by Sprint 6 (Payroll Processing) when generating pay slips.
  #
  # Distinction:
  #   - Approved PAID leave  → no LOP, no salary reduction
  #   - Approved LOP leave   → LOP, salary reduced proportionally
  #   - Unapproved absences  → LOP, salary reduced proportionally
  class LopCalculator
    attr_reader :summary

    def initialize(attendance_summary:)
      @summary = attendance_summary
    end

    # Number of loss-of-pay days for the month
    def lop_days
      summary.lop_days
    end

    # Fraction of salary to be paid: paid_days / total_working_days
    # Returns 1.0 if total_working_days is zero (edge case guard)
    def proration_factor
      summary.proration_factor
    end

    # Convenience: amount to deduct given a monthly gross
    def lop_deduction(monthly_gross)
      per_day = monthly_gross / summary.total_working_days
      (per_day * lop_days).round(2)
    end
  end
end
