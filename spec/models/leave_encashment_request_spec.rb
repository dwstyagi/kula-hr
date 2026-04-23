require "rails_helper"

RSpec.describe LeaveEncashmentRequest, type: :model do
  let(:tenant)   { create(:tenant) }
  let(:employee) { create(:employee, tenant: tenant, employment_status: :active) }
  let(:fy)       { LeaveBalance.current_financial_year }

  before { set_tenant(tenant) }

  let!(:earned_type) do
    create(:leave_type, :earned, tenant: tenant,
           annual_quota: 15, carry_forward: true, max_carry_forward: 6)
  end

  def build_request(overrides = {})
    LeaveEncashmentRequest.new({
      tenant:         tenant,
      employee:       employee,
      leave_type:     earned_type,
      financial_year: fy,
      number_of_days: 6
    }.merge(overrides))
  end

  def with_march(&block)
    travel_to Date.new(Date.today.year, 3, 15, &block)
  end

  describe "validations" do
    before do
      create(:leave_balance, tenant: tenant, employee: employee,
             leave_type: earned_type, financial_year: fy,
             total_days: 15, used_days: 5, remaining_days: 10)
    end

    it "is valid when submitted in March with eligible balance" do
      with_march { expect(build_request).to be_valid }
    end

    it "is invalid outside of March" do
      travel_to Date.new(Date.today.year, 5, 1) do
        req = build_request
        expect(req).not_to be_valid
        expect(req.errors[:base]).to include("Encashment requests can only be submitted in March")
      end
    end

    it "is invalid for non-carry-forward leave types" do
      cl_type = create(:leave_type, :casual, tenant: tenant)
      with_march do
        req = build_request(leave_type: cl_type)
        expect(req).not_to be_valid
        expect(req.errors[:base].first).to include("not eligible for encashment")
      end
    end

    it "is invalid when employee has no carry-forward eligible days" do
      LeaveBalance.find_by(employee: employee, leave_type: earned_type, financial_year: fy)
                  &.update_columns(used_days: 15, remaining_days: 0)
      with_march do
        req = build_request
        expect(req).not_to be_valid
        expect(req.errors[:base].first).to include("no carry-forward eligible")
      end
    end

    it "prevents duplicate request for same leave type and FY" do
      with_march do
        create(:leave_encashment_request, tenant: tenant, employee: employee,
               leave_type: earned_type, financial_year: fy, number_of_days: 6)
        req = build_request
        expect(req).not_to be_valid
        expect(req.errors[:base].first).to include("already submitted")
      end
    end
  end

  describe "enums" do
    it "defaults to pending" do
      req = LeaveEncashmentRequest.new
      expect(req.status).to eq("pending")
    end
  end
end
