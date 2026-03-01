require "rails_helper"

RSpec.describe Payslip, type: :model do
  let(:tenant)   { create(:tenant) }
  let(:hr_user)  { create(:user, :hr_admin) }
  let(:run)      { create(:payroll_run, tenant: tenant, initiated_by: hr_user) }
  let(:employee) { create(:employee, tenant: tenant) }

  before { set_tenant(tenant) }

  subject { build(:payslip, tenant: tenant, payroll_run: run, employee: employee) }

  # ── Associations ─────────────────────────────────────────────────────────

  describe "associations" do
    it { is_expected.to belong_to(:tenant).optional }
    it { is_expected.to belong_to(:payroll_run) }
    it { is_expected.to belong_to(:employee) }
    it { is_expected.to have_many(:line_items).class_name("PayslipLineItem").dependent(:destroy) }
  end

  # ── Validations ───────────────────────────────────────────────────────────

  describe "validations" do
    it { is_expected.to validate_presence_of(:month) }
    it { is_expected.to validate_presence_of(:year) }
    it { is_expected.to validate_inclusion_of(:status).in_array(Payslip::STATUSES) }

    it "rejects a duplicate employee for the same payroll run" do
      create(:payslip, tenant: tenant, payroll_run: run, employee: employee)
      dup = build(:payslip, tenant: tenant, payroll_run: run, employee: employee)
      dup.valid?
      expect(dup.errors[:employee_id]).not_to be_empty
    end

    it "allows same employee in different payroll runs" do
      other_run = create(:payroll_run, tenant: tenant, initiated_by: hr_user, month: 2, year: 2026)
      create(:payslip, tenant: tenant, payroll_run: run,       employee: employee)
      dup = build(:payslip,  tenant: tenant, payroll_run: other_run, employee: employee)
      expect(dup).to be_valid
    end
  end

  # ── STATUSES constant ─────────────────────────────────────────────────────

  describe "STATUSES" do
    it "includes generated, revised, locked" do
      expect(Payslip::STATUSES).to contain_exactly("generated", "revised", "locked")
    end
  end

  # ── Status helpers ────────────────────────────────────────────────────────

  describe "#locked?" do
    it "returns true when status is locked" do
      expect(build(:payslip, :locked)).to be_locked
    end

    it "returns false when status is generated" do
      expect(build(:payslip)).not_to be_locked
    end
  end

  describe "#revised?" do
    it "returns true when status is revised" do
      expect(build(:payslip, :revised)).to be_revised
    end

    it "returns false when status is generated" do
      expect(build(:payslip)).not_to be_revised
    end
  end

  describe "#generated?" do
    it "returns true when status is generated" do
      expect(build(:payslip)).to be_generated
    end

    it "returns false when status is locked" do
      expect(build(:payslip, :locked)).not_to be_generated
    end
  end

  # ── Scopes ────────────────────────────────────────────────────────────────

  describe ".locked scope" do
    it "returns only locked payslips" do
      emp2 = create(:employee, tenant: tenant)
      create(:payslip, :locked,    tenant: tenant, payroll_run: run, employee: employee)
      create(:payslip,             tenant: tenant, payroll_run: run, employee: emp2)

      expect(Payslip.locked.count).to eq(1)
      expect(Payslip.locked.first.status).to eq("locked")
    end
  end

  describe ".revised scope" do
    it "returns only payslips with is_revised flag" do
      emp2 = create(:employee, tenant: tenant)
      create(:payslip, :revised, tenant: tenant, payroll_run: run, employee: employee)
      create(:payslip,           tenant: tenant, payroll_run: run, employee: emp2)

      expect(Payslip.revised.count).to eq(1)
    end
  end

  # ── Computed Helpers ──────────────────────────────────────────────────────

  describe "#ctc_this_month" do
    it "sums gross_pay + employer_pf + employer_esi" do
      payslip = build(:payslip, gross_pay: 50_000, employer_pf: 1_800, employer_esi: 500)
      expect(payslip.ctc_this_month).to eq(52_300)
    end

    it "works when employer_esi is 0" do
      payslip = build(:payslip, gross_pay: 80_000, employer_pf: 1_800, employer_esi: 0)
      expect(payslip.ctc_this_month).to eq(81_800)
    end
  end

  describe "#proration_factor" do
    it "returns 1.0 when fully attended" do
      payslip = build(:payslip, total_working_days: 22, paid_days: 22)
      expect(payslip.proration_factor).to eq(1.0)
    end

    it "calculates fractional factor for LOP" do
      payslip = build(:payslip, total_working_days: 22, paid_days: 20)
      expect(payslip.proration_factor).to eq((20.0 / 22).round(4))
    end

    it "returns 1.0 when total_working_days is zero (no division by zero)" do
      payslip = build(:payslip, total_working_days: 0, paid_days: 0)
      expect(payslip.proration_factor).to eq(1.0)
    end
  end

  describe "#period_label" do
    it "returns month name and year" do
      payslip = build(:payslip, month: 3, year: 2026)
      expect(payslip.period_label).to eq("March 2026")
    end
  end

  # ── Line Item Helpers ─────────────────────────────────────────────────────

  describe "#earnings" do
    it "returns earning line items ordered by sort_order" do
      payslip = create(:payslip, tenant: tenant, payroll_run: run, employee: employee)
      hra   = create(:payslip_line_item, payslip: payslip, component_name: "HRA",   component_type: "earning", sort_order: 2)
      basic = create(:payslip_line_item, payslip: payslip, component_name: "Basic", component_type: "earning", sort_order: 1)
      create(:payslip_line_item, :deduction, payslip: payslip)

      expect(payslip.earnings.to_a).to eq([ basic, hra ])
    end
  end

  describe "#deductions" do
    it "returns deduction line items only" do
      payslip = create(:payslip, tenant: tenant, payroll_run: run, employee: employee)
      create(:payslip_line_item, payslip: payslip, component_name: "Basic", component_type: "earning")
      pf = create(:payslip_line_item, :deduction, payslip: payslip)

      expect(payslip.deductions.to_a).to eq([ pf ])
    end
  end

  # ── recalculate_totals! ───────────────────────────────────────────────────

  describe "#recalculate_totals!" do
    let(:payslip) do
      create(:payslip, tenant: tenant, payroll_run: run, employee: employee,
             gross_pay: 0, total_deductions: 0, net_pay: 0)
    end

    it "recomputes gross from earning line items" do
      create(:payslip_line_item, payslip: payslip, component_name: "Basic", component_type: "earning", amount: 30_000)
      create(:payslip_line_item, payslip: payslip, component_name: "HRA",   component_type: "earning", amount: 15_000)
      payslip.recalculate_totals!
      expect(payslip.gross_pay).to eq(45_000)
    end

    it "recomputes total_deductions from deduction line items" do
      create(:payslip_line_item, payslip: payslip, component_name: "Basic", component_type: "earning", amount: 30_000)
      create(:payslip_line_item, :deduction, payslip: payslip, amount: 1_800)
      payslip.recalculate_totals!
      expect(payslip.total_deductions).to eq(1_800)
    end

    it "sets net_pay = gross - deductions" do
      create(:payslip_line_item, payslip: payslip, component_name: "Basic", component_type: "earning", amount: 40_000)
      create(:payslip_line_item, :deduction, payslip: payslip, amount: 2_000)
      payslip.recalculate_totals!
      expect(payslip.net_pay).to eq(38_000)
    end

    it "floors net_pay at 0 when deductions exceed gross" do
      create(:payslip_line_item, :deduction, payslip: payslip, amount: 5_000)
      payslip.recalculate_totals!
      expect(payslip.net_pay).to eq(0)
    end
  end
end
