require "rails_helper"

RSpec.describe Attendance::LopCalculator do
  let(:tenant)   { create(:tenant) }
  let(:employee) { create(:employee, tenant: tenant) }

  before { set_tenant(tenant) }

  # Helper: build a summary with computed derived fields
  def summary_with(total:, present:, approved: 0, lop_leaves: 0, half_days: 0)
    create(:attendance_summary, tenant: tenant, employee: employee,
           total_working_days: total, days_present: present,
           approved_leaves: approved, lop_leaves: lop_leaves, half_days: half_days)
  end

  describe "#lop_days" do
    it "returns 0 when employee was fully present" do
      calc = described_class.new(attendance_summary: summary_with(total: 22, present: 22))
      expect(calc.lop_days).to eq(0)
    end

    it "returns unapproved absences as LOP when no LOP leave" do
      # unapproved = 22 - 20 - 0 = 2, lop_leaves = 0 → lop_days = 2
      calc = described_class.new(attendance_summary: summary_with(total: 22, present: 20))
      expect(calc.lop_days).to eq(2)
    end

    it "includes approved LOP leaves in lop_days" do
      # unapproved = 22 - 20 - 0 - 1 = 1, lop_leaves = 1 → lop_days = 2
      calc = described_class.new(attendance_summary: summary_with(total: 22, present: 20, lop_leaves: 1))
      expect(calc.lop_days).to eq(2)
    end

    it "does NOT count approved PAID leaves as LOP" do
      # approved paid leaves don't contribute to LOP
      # unapproved = 22 - 20 - 2 = 0, lop_days = 0
      calc = described_class.new(attendance_summary: summary_with(total: 22, present: 20, approved: 2))
      expect(calc.lop_days).to eq(0)
    end
  end

  describe "#proration_factor" do
    it "returns 1.0 when there is no LOP" do
      calc = described_class.new(attendance_summary: summary_with(total: 22, present: 22))
      expect(calc.proration_factor).to eq(1.0)
    end

    it "returns the fraction of paid days over total" do
      # 2 LOP days out of 22 → paid = 20, factor = 20/22
      calc = described_class.new(attendance_summary: summary_with(total: 22, present: 20))
      expect(calc.proration_factor).to be_within(0.0001).of(20.0 / 22.0)
    end

    it "returns 1.0 if total_working_days is 0 (guard)" do
      summary = build(:attendance_summary, tenant: tenant, employee: employee, total_working_days: 0)
      calc = described_class.new(attendance_summary: summary)
      expect(calc.proration_factor).to eq(1.0)
    end
  end

  describe "#lop_deduction" do
    it "computes the salary deduction proportional to LOP days" do
      # 2 LOP days out of 22, monthly gross = 22_000
      # per_day = 22_000 / 22 = 1_000, deduction = 1_000 * 2 = 2_000
      calc = described_class.new(attendance_summary: summary_with(total: 22, present: 20))
      expect(calc.lop_deduction(22_000)).to eq(2_000)
    end

    it "returns 0 deduction when no LOP days" do
      calc = described_class.new(attendance_summary: summary_with(total: 22, present: 22))
      expect(calc.lop_deduction(50_000)).to eq(0)
    end
  end
end
