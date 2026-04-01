require "rails_helper"

RSpec.describe Dashboard::EmployeeDashboardService do
  let(:tenant) { create(:tenant, :active) }
  let(:employee) { create(:employee, tenant: tenant) }

  before { set_tenant(tenant) }

  describe "#call" do
    context "with no payslips" do
      it "returns nil/zero values" do
        result = described_class.new(employee: employee).call

        expect(result.latest_payslip).to be_nil
        expect(result.mom_change).to be_nil
        expect(result.ytd_gross).to eq(0)
        expect(result.ytd_net).to eq(0)
      end
    end

    context "with payslips" do
      # Use April and May of the current FY so YTD filter always matches
      let(:fy_start_year) { Date.current.month >= 4 ? Date.current.year : Date.current.year - 1 }
      let!(:run1) { create(:payroll_run, :approved, tenant: tenant, month: 4, year: fy_start_year) }
      let!(:run2) { create(:payroll_run, :approved, tenant: tenant, month: 5, year: fy_start_year) }
      let!(:payslip1) do
        create(:payslip, tenant: tenant, employee: employee, payroll_run: run1,
               month: 4, year: fy_start_year, gross_pay: 50_000, net_pay: 40_000, total_deductions: 10_000)
      end
      let!(:payslip2) do
        create(:payslip, tenant: tenant, employee: employee, payroll_run: run2,
               month: 5, year: fy_start_year, gross_pay: 55_000, net_pay: 44_000, total_deductions: 11_000)
      end

      it "returns latest and previous payslips" do
        result = described_class.new(employee: employee).call

        expect(result.latest_payslip).to eq(payslip2)
        expect(result.previous_payslip).to eq(payslip1)
      end

      it "calculates MoM change" do
        result = described_class.new(employee: employee).call

        expected_change = ((44_000 - 40_000).to_f / 40_000 * 100).round(1)
        expect(result.mom_change).to eq(expected_change)
      end

      it "calculates YTD totals" do
        result = described_class.new(employee: employee).call

        expect(result.ytd_gross).to eq(105_000)
        expect(result.ytd_net).to eq(84_000)
      end

      it "returns last 3 recent payslips" do
        run3 = create(:payroll_run, :approved, tenant: tenant, month: 6, year: fy_start_year)
        payslip3 = create(:payslip, tenant: tenant, employee: employee, payroll_run: run3,
                          month: 6, year: fy_start_year, gross_pay: 55_000, net_pay: 44_000, total_deductions: 11_000)

        result = described_class.new(employee: employee).call

        expect(result.recent_payslips.size).to eq(3)
        expect(result.recent_payslips).to include(payslip1, payslip2, payslip3)
      end

      context "with deduction line items" do
        before do
          create(:payslip_line_item, :deduction, payslip: payslip1,
                 component_name: "PF", amount: 1_800)
          create(:payslip_line_item, :deduction, payslip: payslip2,
                 component_name: "PF", amount: 1_800)
          create(:payslip_line_item, :deduction, payslip: payslip1,
                 component_name: "TDS", amount: 5_000)
        end

        it "returns YTD component totals" do
          result = described_class.new(employee: employee).call

          expect(result.ytd_pf).to eq(3_600)
          expect(result.ytd_tds).to eq(5_000)
        end
      end
    end

    context "current month payroll status" do
      it "returns nil when no payroll run exists" do
        result = described_class.new(employee: employee).call

        expect(result.current_month_payroll_status).to be_nil
      end

      it "returns status when payroll run exists for current month" do
        create(:payroll_run, tenant: tenant, month: Date.current.month, year: Date.current.year, status: "processing")

        result = described_class.new(employee: employee).call

        expect(result.current_month_payroll_status).to be_present
        expect(result.current_month_payroll_status[:status]).to eq("processing")
        expect(result.current_month_payroll_status[:period]).to eq(Date.current.strftime("%B %Y"))
      end
    end

    context "attendance summary" do
      it "returns nil when no attendance summary exists" do
        result = described_class.new(employee: employee).call

        expect(result.attendance_summary).to be_nil
      end

      it "returns current month attendance summary" do
        summary = create(:attendance_summary, tenant: tenant, employee: employee,
                         month: Date.current.month, year: Date.current.year,
                         total_working_days: 22, days_present: 20, paid_days: 20, lop_days: 2)

        result = described_class.new(employee: employee).call

        expect(result.attendance_summary).to eq(summary)
      end
    end

    context "tax declaration fields" do
      it "returns zero when no tax declaration exists" do
        result = described_class.new(employee: employee).call

        expect(result.monthly_tds).to eq(0)
        expect(result.total_declared_investments).to eq(0)
      end

      it "returns tax declaration values" do
        fy = if Date.current.month >= 4
               "#{Date.current.year}-#{(Date.current.year + 1).to_s.last(2)}"
        else
               "#{Date.current.year - 1}-#{Date.current.year.to_s.last(2)}"
        end
        create(:tax_declaration, tenant: tenant, employee: employee, financial_year: fy,
               estimated_monthly_tds: 5_000, total_declared_investments: 150_000)

        result = described_class.new(employee: employee).call

        expect(result.monthly_tds).to eq(5_000)
        expect(result.total_declared_investments).to eq(150_000)
      end
    end

    context "profile completeness" do
      it "returns 100% when all fields are filled" do
        employee.update_columns(
          bank_account_number: "1234567890",
          pan_number: "ABCDE1234F",
          aadhaar_number: "123456789012",
          phone: "9876543210",
          date_of_birth: Date.new(1990, 1, 1),
          current_address: "123 Main St"
        )

        result = described_class.new(employee: employee).call

        expect(result.profile_completeness[:percentage]).to eq(100)
        expect(result.profile_completeness[:missing_fields]).to be_empty
      end

      it "returns correct percentage and missing fields" do
        employee.update_columns(
          bank_account_number: nil,
          pan_number: nil,
          aadhaar_number: nil,
          phone: "9876543210",
          date_of_birth: Date.new(1990, 1, 1),
          current_address: "123 Main St"
        )

        result = described_class.new(employee: employee).call

        expect(result.profile_completeness[:percentage]).to eq(50)
        expect(result.profile_completeness[:missing_fields]).to contain_exactly("bank_account_number", "pan_number", "aadhaar_number")
      end
    end
  end
end
