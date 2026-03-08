require "rails_helper"

RSpec.describe Dashboard::AdminDashboardService do
  let(:tenant) { create(:tenant, :active) }

  before { set_tenant(tenant) }

  describe "#call" do
    context "with no payroll runs" do
      it "returns empty/default data" do
        result = described_class.new(tenant: tenant).call

        expect(result.current_run).to be_nil
        expect(result.current_run_status).to eq("No Payroll Run")
        expect(result.current_run_net).to eq(0)
        expect(result.payroll_trend).to be_empty
        expect(result.deduction_breakdown).to eq({})
        expect(result.recent_activity).to be_empty
      end
    end

    context "with payroll runs" do
      let!(:run1) do
        create(:payroll_run, :approved, tenant: tenant, month: 1, year: 2026,
               total_gross: 100_000, total_net_pay: 85_000, total_employer_cost: 110_000)
      end
      let!(:run2) do
        create(:payroll_run, :approved, tenant: tenant, month: 2, year: 2026,
               total_gross: 120_000, total_net_pay: 100_000, total_employer_cost: 130_000)
      end

      it "returns current run info" do
        result = described_class.new(tenant: tenant).call

        expect(result.current_run).to eq(run2)
        expect(result.current_run_status).to eq("Approved")
        expect(result.current_run_net).to eq(100_000)
      end

      it "returns payroll trend in chronological order" do
        result = described_class.new(tenant: tenant).call

        expect(result.payroll_trend.size).to eq(2)
        expect(result.payroll_trend.first[:label]).to eq("Jan 2026")
        expect(result.payroll_trend.last[:label]).to eq("Feb 2026")
      end

      it "returns recent activity" do
        result = described_class.new(tenant: tenant).call

        expect(result.recent_activity.size).to eq(2)
      end

      context "with pending leave requests" do
        let(:department) { create(:department, tenant: tenant) }
        let(:designation) { create(:designation, tenant: tenant) }
        let!(:employee) do
          create(:employee, tenant: tenant, department: department, designation: designation)
        end
        let!(:leave_type) { create(:leave_type, tenant: tenant) }

        it "returns pending leave count and requests" do
          leave_request = LeaveRequest.new(
            tenant: tenant,
            employee: employee,
            leave_type: leave_type,
            from_date: Date.today + 10,
            to_date: Date.today + 12,
            number_of_days: 3,
            reason: "Vacation",
            status: :pending
          )
          leave_request.save(validate: false)

          result = described_class.new(tenant: tenant).call

          expect(result.pending_leave_count).to eq(1)
          expect(result.pending_leave_requests.first).to eq(leave_request)
        end

        it "returns zero pending count when no pending leaves" do
          result = described_class.new(tenant: tenant).call

          expect(result.pending_leave_count).to eq(0)
          expect(result.pending_leave_requests).to be_empty
        end
      end

      context "with deductions" do
        let!(:payslip) { create(:payslip, tenant: tenant, payroll_run: run2) }
        let!(:pf_item) do
          create(:payslip_line_item, :deduction, payslip: payslip,
                 component_name: "PF", amount: 1_800)
        end
        let!(:tds_item) do
          create(:payslip_line_item, :deduction, payslip: payslip,
                 component_name: "TDS", amount: 3_000)
        end

        it "returns deduction breakdown" do
          result = described_class.new(tenant: tenant).call

          expect(result.deduction_breakdown).to include("PF" => 1_800, "TDS" => 3_000)
        end
      end
    end
  end
end
