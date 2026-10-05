require "rails_helper"

RSpec.describe Statutory::PfWageCeiling do
  describe ".on" do
    it "is ₹15,000 up to 16 September 2026" do
      expect(described_class.on(Date.new(2026, 9, 16))).to eq(15_000)
    end

    it "is ₹25,000 from 17 September 2026" do
      expect(described_class.on(Date.new(2026, 9, 17))).to eq(25_000)
    end
  end

  describe ".for_month" do
    it "uses ₹15,000 for months before the change" do
      expect(described_class.for_month(8, 2026)).to eq(15_000)
    end

    it "prorates September 2026 by calendar days (16 days at 15k, 14 at 25k)" do
      expect(described_class.for_month(9, 2026)).to eq(BigDecimal("19666.67"))
    end

    it "uses ₹25,000 from October 2026" do
      expect(described_class.for_month(10, 2026)).to eq(25_000)
    end
  end
end
