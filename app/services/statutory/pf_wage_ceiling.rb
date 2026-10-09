module Statutory
  # Statutory EPF/EPS/EDLI monthly wage ceiling, by the date it took effect.
  #
  # When the ceiling changes, ADD an entry — never edit a past one. Re-running
  # payroll for an earlier month must reproduce the ceiling applied then.
  #
  # A wage month that contains a change is prorated by calendar days: the
  # ceiling is the day-weighted average of the ceilings in force during the
  # month. September 2026 = (16 × 15,000 + 14 × 25,000) / 30 = 19,666.67.
  module PfWageCeiling
    CEILINGS = [
      [ Date.new(2014, 9, 1),  15_000 ],
      # S.O. 5109(E), Code on Social Security 2020, in force from publication
      # in the Gazette on 17 September 2026.
      [ Date.new(2026, 9, 17), 25_000 ]
    ].freeze

    module_function

    # Ceiling in force on a given date.
    def on(date)
      CEILINGS.reverse_each { |from, amount| return amount.to_d if date >= from }
      CEILINGS.first.last.to_d
    end

    # Ceiling for a wage month (prorated if it changed during the month).
    def for_month(month, year)
      start  = Date.new(year.to_i, month.to_i, 1)
      days   = (start..start.end_of_month).to_a
      (days.sum { |date| on(date) } / days.size).round(2)
    end

    # Ceiling for the month containing today — for previews and calculators
    # that are not tied to a payroll period.
    def current
      for_month(Date.current.month, Date.current.year)
    end
  end
end
