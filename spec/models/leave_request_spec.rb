require "rails_helper"

RSpec.describe LeaveRequest, type: :model do
  let(:tenant)     { create(:tenant) }
  let(:employee)   { create(:employee, tenant: tenant) }
  let(:leave_type) { create(:leave_type, :casual, tenant: tenant) }
  let(:balance)    { create(:leave_balance, tenant: tenant, employee: employee,
                             leave_type: leave_type, total_days: 12, remaining_days: 12) }

  before { set_tenant(tenant) }

  describe "status enum" do
    it "has pending as default status" do
      lr = build(:leave_request, tenant: tenant, employee: employee, leave_type: leave_type)
      expect(lr.status).to eq("pending")
    end

    it { is_expected.to define_enum_for(:status).with_values(pending: 0, approved: 1, rejected: 2, cancelled: 3) }
  end

  describe "#calculate_number_of_days (before_validation)" do
    it "counts only business days in the range" do
      # Monday to Friday = 5 business days
      mon = Date.today.next_occurring(:monday) + 14
      fri = mon + 4
      lr = build(:leave_request, tenant: tenant, employee: employee,
                 leave_type: leave_type, from_date: mon, to_date: fri)
      lr.validate
      expect(lr.number_of_days).to eq(5)
    end

    it "counts a single-day request as 1 day" do
      day = Date.today.next_occurring(:wednesday)
      lr = build(:leave_request, tenant: tenant, employee: employee,
                 leave_type: leave_type, from_date: day, to_date: day)
      lr.validate
      expect(lr.number_of_days).to eq(1)
    end

    it "excludes weekends in a multi-week range" do
      # Mon to next Mon = 6 business days (Mon–Fri + Mon)
      mon = Date.today.next_occurring(:monday) + 14
      next_mon = mon + 7
      lr = build(:leave_request, tenant: tenant, employee: employee,
                 leave_type: leave_type, from_date: mon, to_date: next_mon)
      lr.validate
      expect(lr.number_of_days).to eq(6)
    end
  end

  describe "validations" do
    describe "to_date_on_or_after_from_date" do
      it "is invalid if to_date is before from_date" do
        lr = build(:leave_request, tenant: tenant, employee: employee, leave_type: leave_type,
                   from_date: Date.today + 7, to_date: Date.today + 5)
        expect(lr).not_to be_valid
        expect(lr.errors[:to_date]).not_to be_empty
      end
    end

    describe "from_date_not_in_past (on: :create)" do
      it "rejects past from_date on create" do
        lr = build(:leave_request, tenant: tenant, employee: employee, leave_type: leave_type,
                   from_date: Date.today - 1, to_date: Date.today)
        expect(lr).not_to be_valid
        expect(lr.errors[:from_date]).to include("cannot be in the past")
      end
    end

    describe "no_overlapping_requests (on: :create)" do
      before { balance }   # ensure balance exists

      let!(:existing) do
        lr = build(:leave_request, tenant: tenant, employee: employee, leave_type: leave_type,
                   from_date: Date.today + 7, to_date: Date.today + 9)
        lr.save(validate: false)
        lr
      end

      it "rejects a request that overlaps an existing request" do
        overlapping = build(:leave_request, tenant: tenant, employee: employee, leave_type: leave_type,
                            from_date: Date.today + 8, to_date: Date.today + 10)
        expect(overlapping).not_to be_valid
        expect(overlapping.errors[:base]).to include(match(/overlaps/))
      end

      it "allows a non-overlapping request" do
        non_overlap = build(:leave_request, tenant: tenant, employee: employee, leave_type: leave_type,
                            from_date: Date.today + 14, to_date: Date.today + 14)
        non_overlap.valid?
        expect(non_overlap.errors[:base]).not_to include(match(/overlaps/))
      end
    end

    describe "sufficient_balance (on: :create)" do
      before { balance }

      it "rejects when requested days exceed remaining balance" do
        lr = build(:leave_request, tenant: tenant, employee: employee, leave_type: leave_type,
                   from_date: Date.today.next_occurring(:monday) + 14,
                   to_date:   Date.today.next_occurring(:monday) + 40)   # many days
        lr.valid?
        expect(lr.errors[:base]).to include(match(/Insufficient/i))
      end

      it "allows LOP leave without a balance" do
        lop_type = create(:leave_type, :lop, tenant: tenant)
        lr = build(:leave_request, tenant: tenant, employee: employee, leave_type: lop_type,
                   from_date: Date.today + 7, to_date: Date.today + 7)
        lr.valid?
        expect(lr.errors[:base]).not_to include(match(/balance/i))
      end
    end

    describe "employee_is_active (on: :create)" do
      it "rejects leave for an inactive employee" do
        resigned = create(:employee, :resigned, tenant: tenant)
        lr = build(:leave_request, tenant: tenant, employee: resigned, leave_type: leave_type,
                   from_date: Date.today + 7, to_date: Date.today + 7)
        expect(lr).not_to be_valid
        expect(lr.errors[:base]).to include(match(/inactive/))
      end
    end
  end

  describe "scopes" do
    it ".pending_approval returns pending requests" do
      pending_req  = build(:leave_request, :pending,   tenant: tenant, employee: employee, leave_type: leave_type)
      approved_req = build(:leave_request, :approved,  tenant: tenant, employee: employee, leave_type: leave_type)
      pending_req.save(validate: false)
      approved_req.save(validate: false)

      expect(LeaveRequest.pending_approval).to include(pending_req)
      expect(LeaveRequest.pending_approval).not_to include(approved_req)
    end

    it ".for_month filters requests overlapping the given month" do
      in_month  = build(:leave_request, tenant: tenant, employee: employee, leave_type: leave_type,
                         from_date: Date.new(2025, 1, 6), to_date: Date.new(2025, 1, 8))
      out_month = build(:leave_request, tenant: tenant, employee: employee, leave_type: leave_type,
                         from_date: Date.new(2025, 2, 3), to_date: Date.new(2025, 2, 5))
      in_month.save(validate: false)
      out_month.save(validate: false)

      results = LeaveRequest.for_month(1, 2025)
      expect(results).to include(in_month)
      expect(results).not_to include(out_month)
    end
  end
end
