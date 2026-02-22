require "rails_helper"

RSpec.describe AttendanceSummary, type: :model do
  let(:tenant)   { create(:tenant) }
  let(:employee) { create(:employee, tenant: tenant) }

  before { set_tenant(tenant) }

  describe "validations" do
    subject { build(:attendance_summary, tenant: tenant, employee: employee) }

    it { is_expected.to validate_presence_of(:month) }
    it { is_expected.to validate_presence_of(:year) }
    it { is_expected.to validate_inclusion_of(:month).in_range(1..12) }

    describe "uniqueness per employee, month, year" do
      before { create(:attendance_summary, tenant: tenant, employee: employee) }

      it "rejects duplicate summary for same employee and month" do
        duplicate = build(:attendance_summary, tenant: tenant, employee: employee)
        expect(duplicate).not_to be_valid
      end

      it "allows summary for a different month" do
        other_month = build(:attendance_summary, tenant: tenant, employee: employee,
                            month: Date.today.prev_month.month,
                            year:  Date.today.prev_month.year)
        expect(other_month).to be_valid
      end
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:tenant).optional }
    it { is_expected.to belong_to(:employee) }
  end

  describe "status enum" do
    it { is_expected.to define_enum_for(:status).with_values(draft: 0, locked: 1) }
  end

  describe "before_save :recalculate_derived_fields" do
    it "calculates unapproved_absences from days_present and approved_leaves" do
      summary = create(:attendance_summary, tenant: tenant, employee: employee,
                       total_working_days: 22, days_present: 18,
                       approved_leaves: 2, lop_leaves: 0, half_days: 0)
      # 22 - 18 - 2 - 0 = 2 unapproved
      expect(summary.unapproved_absences).to eq(2)
    end

    it "calculates lop_days as unapproved_absences + lop_leaves" do
      summary = create(:attendance_summary, tenant: tenant, employee: employee,
                       total_working_days: 22, days_present: 18,
                       approved_leaves: 2, lop_leaves: 1, half_days: 0)
      # unapproved = 22 - 18 - 2 - 1 = 1, lop = 1 + 1 = 2
      expect(summary.lop_days).to eq(2)
    end

    it "calculates paid_days as total_working_days minus lop_days" do
      summary = create(:attendance_summary, tenant: tenant, employee: employee,
                       total_working_days: 22, days_present: 20,
                       approved_leaves: 0, lop_leaves: 0, half_days: 0)
      expect(summary.paid_days).to eq(20)
    end

    it "counts half_days as 0.5 each toward effective presence" do
      summary = create(:attendance_summary, tenant: tenant, employee: employee,
                       total_working_days: 22, days_present: 20,
                       approved_leaves: 0, lop_leaves: 0, half_days: 2)
      # effective_present = 20 + 2*0.5 = 21, unapproved = 22 - 21 = 1
      expect(summary.unapproved_absences).to eq(1)
    end

    it "clamps unapproved_absences to 0 when fully accounted" do
      summary = create(:attendance_summary, tenant: tenant, employee: employee,
                       total_working_days: 22, days_present: 22,
                       approved_leaves: 0, lop_leaves: 0, half_days: 0)
      expect(summary.unapproved_absences).to eq(0)
      expect(summary.lop_days).to eq(0)
      expect(summary.paid_days).to eq(22)
    end
  end

  describe "#proration_factor" do
    it "returns paid_days / total_working_days" do
      summary = create(:attendance_summary, tenant: tenant, employee: employee,
                       total_working_days: 22, days_present: 20,
                       approved_leaves: 0, lop_leaves: 0, half_days: 0)
      expect(summary.proration_factor).to be_within(0.0001).of(20.0 / 22.0)
    end

    it "returns 1.0 when total_working_days is zero" do
      summary = build(:attendance_summary, tenant: tenant, employee: employee,
                      total_working_days: 0)
      expect(summary.proration_factor).to eq(1.0)
    end
  end

  describe "#period_label" do
    it "returns a human-readable month/year string" do
      summary = build(:attendance_summary, tenant: tenant, employee: employee,
                      month: 1, year: 2025)
      expect(summary.period_label).to eq("January 2025")
    end
  end

  describe "lock transition" do
    it "can be locked from draft" do
      summary = create(:attendance_summary, tenant: tenant, employee: employee)
      expect { summary.update!(status: :locked) }.not_to raise_error
      expect(summary.reload).to be_locked
    end
  end
end
