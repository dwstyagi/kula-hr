require "rails_helper"

RSpec.describe FinancialYear do
  it "labels April onwards with the year it starts" do
    expect(described_class.label(Date.new(2026, 4, 1))).to eq("2026-27")
  end

  it "labels January–March with the previous year" do
    expect(described_class.label(Date.new(2027, 3, 31))).to eq("2026-27")
  end

  it "labels a payroll period" do
    expect(described_class.for_period(1, 2030)).to eq("2029-30")
  end

  it "positions April first and March last" do
    expect([ described_class.position(4), described_class.position(3) ]).to eq([ 1, 12 ])
  end
end
