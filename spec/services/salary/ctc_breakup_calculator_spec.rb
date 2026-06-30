require "rails_helper"

RSpec.describe Salary::CtcBreakupCalculator do
  let(:tenant) { create(:tenant, state: "Maharashtra") }

  before { set_tenant(tenant) }

  let(:payroll_setting) do
    create(:payroll_setting,
      tenant: tenant,
      pf_employee_rate: 12.0,
      pf_employer_rate: 12.0,
      pf_wage_ceiling: 15_000,
      esi_employee_rate: 0.75,
      esi_employer_rate: 3.25,
      esi_ceiling: 21_000,
      pt_state: "maharashtra"
    )
  end

  let(:pt_slabs) do
    [
      create(:professional_tax_slab, tenant: tenant, state: "Maharashtra", salary_from: 0, salary_to: 7_500, tax_amount: 0, month: nil),
      create(:professional_tax_slab, tenant: tenant, state: "Maharashtra", salary_from: 7_501, salary_to: 10_000, tax_amount: 175, month: nil),
      create(:professional_tax_slab, tenant: tenant, state: "Maharashtra", salary_from: 10_001, salary_to: 999_999, tax_amount: 200, month: nil)
    ]
  end

  # Build a structure: Basic 40%, HRA 20%, Special Allowance 30%, Conveyance flat 1600
  let(:basic_comp) { create(:salary_component, tenant: tenant, name: "Basic", component_type: "earning", calculation_type: "percentage", sort_order: 1) }
  let(:hra_comp) { create(:salary_component, tenant: tenant, name: "HRA", component_type: "earning", calculation_type: "percentage", sort_order: 2) }
  let(:special_comp) { create(:salary_component, tenant: tenant, name: "Special Allowance", component_type: "earning", calculation_type: "percentage", sort_order: 3) }
  let(:conveyance_comp) { create(:salary_component, tenant: tenant, name: "Conveyance Allowance", component_type: "earning", calculation_type: "flat", sort_order: 4) }

  let(:structure) do
    s = create(:salary_structure, tenant: tenant, name: "Standard CTC")
    create(:salary_structure_component, salary_structure: s, salary_component: basic_comp, value: 40)
    create(:salary_structure_component, salary_structure: s, salary_component: hra_comp, value: 20)
    create(:salary_structure_component, salary_structure: s, salary_component: special_comp, value: 30)
    create(:salary_structure_component, salary_structure: s, salary_component: conveyance_comp, value: 1600)
    s.reload
  end

  describe "with ₹12,00,000 annual CTC" do
    let(:annual_ctc) { 1_200_000 }

    subject do
      described_class.call(
        annual_ctc: annual_ctc,
        salary_structure: structure,
        payroll_setting: payroll_setting,
        professional_tax_slabs: pt_slabs
      )
    end

    it "returns a Result struct" do
      expect(subject).to be_a(Salary::CtcBreakupCalculator::Result)
    end

    it "computes correct CTC values" do
      expect(subject.annual_ctc).to eq(1_200_000)
      expect(subject.monthly_ctc).to eq(100_000)
    end

    describe "earnings" do
      it "computes percentage-based earnings correctly" do
        basic = subject.earnings.find { |e| e.name == "Basic" }
        hra = subject.earnings.find { |e| e.name == "HRA" }
        special = subject.earnings.find { |e| e.name == "Special Allowance" }

        # Basic = 40% of 12L / 12 = 40,000/month
        expect(basic.monthly).to eq(40_000)
        expect(basic.annual).to eq(480_000)

        # HRA = 20% of 12L / 12 = 20,000/month
        expect(hra.monthly).to eq(20_000)

        # Special = 30% of 12L / 12 = 30,000/month
        expect(special.monthly).to eq(30_000)
      end

      it "computes flat earnings correctly" do
        conveyance = subject.earnings.find { |e| e.name == "Conveyance Allowance" }
        expect(conveyance.monthly).to eq(1_600)
        expect(conveyance.annual).to eq(19_200)
      end

      it "computes gross correctly" do
        # 40000 + 20000 + 30000 + 1600 = 91600
        expect(subject.gross_monthly).to eq(91_600)
        expect(subject.gross_annual).to eq(91_600 * 12)
      end
    end

    describe "deductions" do
      it "computes Employee PF correctly (capped at ceiling)" do
        pf = subject.deductions.find { |d| d.name == "Employee PF" }
        # Basic is 40,000 > ceiling 15,000, so PF base = 15,000
        # PF = 12% of 15,000 = 1,800
        expect(pf.monthly).to eq(1_800)
        expect(pf.annual).to eq(21_600)
      end

      it "computes ESI as 0 when gross exceeds ceiling" do
        esi = subject.deductions.find { |d| d.name == "ESI" }
        # Gross 91,600 > ESI ceiling 21,000 → ESI = 0
        expect(esi.monthly).to eq(0)
      end

      it "computes Professional Tax from state slabs" do
        pt = subject.deductions.find { |d| d.name == "Professional Tax" }
        # Gross 91,600 falls in 10,001–999,999 slab → PT = 200
        expect(pt.monthly).to eq(200)
      end
    end

    describe "employer contributions" do
      it "computes Employer PF correctly (capped at ceiling)" do
        epf = subject.employer_contributions.find { |c| c.name == "Employer PF" }
        # Same as employee PF: 12% of min(40000, 15000) = 1,800
        expect(epf.monthly).to eq(1_800)
      end

      it "computes Employer ESI as 0 when gross exceeds ceiling" do
        eesi = subject.employer_contributions.find { |c| c.name == "Employer ESI" }
        expect(eesi.monthly).to eq(0)
      end
    end

    describe "net salary" do
      it "computes net = gross - deductions" do
        # Gross: 91,600 - PF: 1,800 - ESI: 0 - PT: 200 = 89,600
        expect(subject.net_monthly).to eq(89_600)
        expect(subject.net_annual).to eq(89_600 * 12)
      end
    end
  end

  describe "with low CTC (ESI applicable)" do
    let(:annual_ctc) { 240_000 } # 20,000/month

    subject do
      described_class.call(
        annual_ctc: annual_ctc,
        salary_structure: structure,
        payroll_setting: payroll_setting,
        professional_tax_slabs: pt_slabs
      )
    end

    it "computes earnings correctly" do
      basic = subject.earnings.find { |e| e.name == "Basic" }
      # Basic = 40% of 2.4L / 12 = 8,000/month
      expect(basic.monthly).to eq(8_000)
    end

    it "applies ESI when gross is within ceiling" do
      esi = subject.deductions.find { |d| d.name == "ESI" }
      # Gross = 8000 + 4000 + 6000 + 1600 = 19,600
      # 19,600 <= 21,000 ceiling → ESI = 0.75% of 19,600 = 147.00
      expect(esi.monthly).to eq(147.0)
    end

    it "applies Employer ESI when gross is within ceiling" do
      eesi = subject.employer_contributions.find { |c| c.name == "Employer ESI" }
      # 3.25% of 19,600 = 637.00
      expect(eesi.monthly).to eq(637.0)
    end

    it "applies PF on full basic (below ceiling)" do
      pf = subject.deductions.find { |d| d.name == "Employee PF" }
      # Basic 8,000 < ceiling 15,000 → PF = 12% of 8,000 = 960
      expect(pf.monthly).to eq(960)
    end

    it "applies correct PT slab" do
      pt = subject.deductions.find { |d| d.name == "Professional Tax" }
      # Gross 19,600 falls in 10,001–999,999 slab → PT = 200
      expect(pt.monthly).to eq(200)
    end
  end

  describe "with very low CTC (no PT)" do
    let(:annual_ctc) { 72_000 } # 6,000/month

    subject do
      described_class.call(
        annual_ctc: annual_ctc,
        salary_structure: structure,
        payroll_setting: payroll_setting,
        professional_tax_slabs: pt_slabs
      )
    end

    it "returns 0 PT when gross falls in zero slab" do
      pt = subject.deductions.find { |d| d.name == "Professional Tax" }
      # Gross = 2400 + 1200 + 1800 + 1600 = 7000
      # 7000 falls in 0–7500 slab → PT = 0
      expect(pt.monthly).to eq(0)
    end
  end

  describe "with no PT slabs configured" do
    subject do
      described_class.call(
        annual_ctc: 1_200_000,
        salary_structure: structure,
        payroll_setting: payroll_setting,
        professional_tax_slabs: []
      )
    end

    it "returns 0 for PT" do
      pt = subject.deductions.find { |d| d.name == "Professional Tax" }
      expect(pt.monthly).to eq(0)
    end
  end

  describe "employer PF in CTC" do
    let(:ctc_setting) do
      create(:payroll_setting, tenant: tenant,
        pf_employee_rate: 12.0, pf_employer_rate: 12.0, pf_wage_ceiling: 15_000,
        pf_admin_charge_rate: 0.5, pf_edli_rate: 0.5,
        employer_pf_in_ctc: true)
    end

    subject do
      described_class.call(annual_ctc: 1_200_000, salary_structure: structure,
                           payroll_setting: ctc_setting, professional_tax_slabs: pt_slabs)
    end

    # carve = employer PF (12% x 15k = 1800) + admin (0.5% = 75) + EDLI (0.5% = 75) = 1950
    it "carves the employer PF charges out of Special Allowance" do
      special = subject.earnings.find { |e| e.name == "Special Allowance" }
      expect(special.monthly).to eq(30_000 - 1_950)
    end

    it "does not touch Basic or HRA" do
      expect(subject.earnings.find { |e| e.name == "Basic" }.monthly).to eq(40_000)
      expect(subject.earnings.find { |e| e.name == "HRA" }.monthly).to eq(20_000)
    end

    it "lowers gross by exactly the carve" do
      # baseline gross (on-top model) = 40000 + 20000 + 30000 + 1600 = 91600
      expect(subject.gross_monthly).to eq(91_600 - 1_950)
    end

    it "itemises PF admin and EDLI in employer contributions" do
      names = subject.employer_contributions.map(&:name)
      expect(names).to include("Employer PF", "PF Admin Charges", "EDLI")
    end

    it "leaves Special Allowance untouched when the flag is off (default)" do
      off = described_class.call(annual_ctc: 1_200_000, salary_structure: structure,
                                 payroll_setting: payroll_setting, professional_tax_slabs: pt_slabs)
      expect(off.earnings.find { |e| e.name == "Special Allowance" }.monthly).to eq(30_000)
    end
  end
end
