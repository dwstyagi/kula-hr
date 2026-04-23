require "rails_helper"

RSpec.describe CompOffRequest, type: :model do
  let(:tenant)   { create(:tenant) }
  let(:employee) { create(:employee, tenant: tenant, employment_status: :active) }

  before { set_tenant(tenant) }

  # Use a Sunday in the past as the default non-working day
  let(:past_sunday) { Date.today.prev_occurring(:sunday) }
  let(:past_weekday) do
    d = Date.today - 2
    d = d - 1 while d.saturday? || d.sunday?
    d
  end

  def build_request(overrides = {})
    CompOffRequest.new({
      tenant:      tenant,
      employee:    employee,
      worked_date: past_sunday,
      reason:      "Worked on weekend"
    }.merge(overrides))
  end

  describe "validations" do
    it "is valid for a past non-working day" do
      expect(build_request).to be_valid
    end

    it "is invalid for a future date" do
      req = build_request(worked_date: Date.today + 1)
      expect(req).not_to be_valid
      expect(req.errors[:worked_date]).to include("must be in the past")
    end

    it "is invalid for today" do
      req = build_request(worked_date: Date.today)
      expect(req).not_to be_valid
      expect(req.errors[:worked_date]).to include("must be in the past")
    end

    it "is invalid for a regular working weekday" do
      req = build_request(worked_date: past_weekday)
      expect(req).not_to be_valid
      expect(req.errors[:worked_date].first).to include("must be a public holiday or weekend")
    end

    it "is valid for a public holiday on a weekday" do
      create(:holiday, tenant: tenant, date: past_weekday, name: "Special Holiday")
      expect(build_request(worked_date: past_weekday)).to be_valid
    end

    context "duplicate request protection" do
      it "blocks a second request when one is pending" do
        create(:comp_off_request, tenant: tenant, employee: employee,
               worked_date: past_sunday, status: :pending)
        req = build_request
        expect(req).not_to be_valid
        expect(req.errors[:base].first).to include("pending comp-off request")
      end

      it "blocks a second request when one is approved" do
        create(:comp_off_request, :approved, tenant: tenant, employee: employee,
               worked_date: past_sunday)
        req = build_request
        expect(req).not_to be_valid
        expect(req.errors[:base].first).to include("approved comp-off request")
      end

      it "allows re-apply after rejection" do
        create(:comp_off_request, :rejected, tenant: tenant, employee: employee,
               worked_date: past_sunday)
        expect(build_request).to be_valid
      end
    end
  end

  describe "enums" do
    it "defaults to pending" do
      expect(CompOffRequest.new.status).to eq("pending")
    end
  end
end
