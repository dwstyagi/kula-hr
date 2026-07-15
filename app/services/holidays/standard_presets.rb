module Holidays
  # Smart defaults for the holiday form: one click adds the standard Indian
  # gazetted holidays instead of ten separate manual entries.
  #
  # FIXED holidays land on the same date every year. Festival dates follow the
  # lunar calendar and shift annually, so they're only offered for years we
  # have confirmed dates for (source: drikpanchang.com panchang).
  class StandardPresets
    FIXED = [
      { name: "New Year's Day", month: 1, day: 1 },
      { name: "Republic Day", month: 1, day: 26 },
      { name: "Labour Day", month: 5, day: 1 },
      { name: "Independence Day", month: 8, day: 15 },
      { name: "Gandhi Jayanti", month: 10, day: 2 },
      { name: "Christmas", month: 12, day: 25 }
    ].freeze

    FESTIVALS_BY_YEAR = {
      2026 => [
        { name: "Holi", month: 3, day: 4 },
        { name: "Good Friday", month: 4, day: 3 },
        { name: "Janmashtami", month: 9, day: 4 },
        { name: "Dussehra (Vijayadashami)", month: 10, day: 20 },
        { name: "Diwali", month: 11, day: 8 },
        { name: "Guru Nanak Jayanti", month: 11, day: 24 }
      ]
    }.freeze

    def self.for_year(year)
      (FIXED + FESTIVALS_BY_YEAR.fetch(year, [])).map do |h|
        { name: h[:name], date: Date.new(year, h[:month], h[:day]) }
      end
    end

    def self.years_with_full_data
      FESTIVALS_BY_YEAR.keys
    end
  end
end
