require "rails_helper"

RSpec.describe Attendance::MonthWindow do
  describe ".open?" do
    it "opens the current month once it reaches its final 7 days" do
      # July 2026 has 31 days, so the window starts on the 25th.
      expect(described_class.open?(7, 2026, today: Date.new(2026, 7, 24))).to be false
      expect(described_class.open?(7, 2026, today: Date.new(2026, 7, 25))).to be true
      expect(described_class.open?(7, 2026, today: Date.new(2026, 7, 31))).to be true
    end

    it "scales the window to short months" do
      # February 2026 has 28 days, so the window starts on the 22nd.
      expect(described_class.open?(2, 2026, today: Date.new(2026, 2, 21))).to be false
      expect(described_class.open?(2, 2026, today: Date.new(2026, 2, 22))).to be true
    end

    it "always allows past months" do
      today = Date.new(2026, 7, 3)
      expect(described_class.open?(6, 2026, today: today)).to be true
      expect(described_class.open?(12, 2025, today: today)).to be true
    end

    it "never allows future months, even inside the current window" do
      expect(described_class.open?(8, 2026, today: Date.new(2026, 7, 31))).to be false
      expect(described_class.open?(1, 2027, today: Date.new(2026, 7, 31))).to be false
    end
  end

  describe ".latest_open" do
    it "is the previous month before the window opens" do
      expect(described_class.latest_open(today: Date.new(2026, 7, 24))).to eq Date.new(2026, 6, 1)
    end

    it "becomes the current month once the window opens" do
      expect(described_class.latest_open(today: Date.new(2026, 7, 25))).to eq Date.new(2026, 7, 1)
    end

    it "rolls back across a year boundary" do
      expect(described_class.latest_open(today: Date.new(2026, 1, 5))).to eq Date.new(2025, 12, 1)
    end

    it "handles a 31st-of-month today, where prev_month has fewer days" do
      expect(described_class.latest_open(today: Date.new(2026, 3, 3))).to eq Date.new(2026, 2, 1)
    end
  end

  describe ".opens_on" do
    it "is the first day of the trailing window" do
      expect(described_class.opens_on(today: Date.new(2026, 7, 10))).to eq Date.new(2026, 7, 25)
      expect(described_class.opens_on(today: Date.new(2026, 2, 10))).to eq Date.new(2026, 2, 22)
    end
  end
end
