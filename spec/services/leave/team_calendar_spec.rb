require "rails_helper"

RSpec.describe Leave::TeamCalendar do
  let(:tenant) { create(:tenant) }
  let!(:payroll_setting) { create(:payroll_setting, tenant: tenant, week_off_pattern: "all_saturdays_sundays") }
  let(:dept)   { create(:department, tenant: tenant) }
  let(:emp1)   { create(:employee, tenant: tenant, department: dept, first_name: "Aman", email: "a@x.com") }
  let(:emp2)   { create(:employee, tenant: tenant, department: dept, first_name: "Bina", email: "b@x.com") }
  let(:casual) { create(:leave_type, :casual, tenant: tenant) }

  before { set_tenant(tenant) }

  def make_leave(employee, from, to, status)
    lr = build(:leave_request, tenant: tenant, employee: employee, leave_type: casual,
               from_date: from, to_date: to, status: status)
    lr.save(validate: false)
    lr
  end

  # January 2025: 31 days; Jan 4 is a Saturday.
  subject(:calendar) { described_class.new(employees: [ emp1, emp2 ], month: 1, year: 2025, tenant: tenant) }

  describe "#days" do
    it "returns one entry per day of the month" do
      expect(calendar.days.size).to eq(31)
    end

    it "flags weekends as week-offs" do
      sat = calendar.days.find { |d| d.date == Date.new(2025, 1, 4) }
      expect(sat.week_off).to be true
      expect(sat).to be_non_working
    end

    it "flags company-wide holidays by name" do
      create(:holiday, tenant: tenant, date: Date.new(2025, 1, 15), name: "Makar Sankranti")
      day = calendar.days.find { |d| d.date == Date.new(2025, 1, 15) }
      expect(day.holiday_name).to eq("Makar Sankranti")
      expect(day).to be_non_working
    end

    it "does not flag location-specific holidays at the column level" do
      loc = create(:work_location, tenant: tenant)
      create(:holiday, tenant: tenant, date: Date.new(2025, 1, 16), name: "Local", work_location: loc)
      day = calendar.days.find { |d| d.date == Date.new(2025, 1, 16) }
      expect(day.holiday_name).to be_nil
    end
  end

  describe "#rows" do
    def cells_for(employee)
      calendar.rows.find { |e, _| e == employee }.last
    end

    it "returns a row per employee" do
      expect(calendar.rows.map(&:first)).to contain_exactly(emp1, emp2)
    end

    it "marks approved leave days with the leave type code" do
      make_leave(emp1, Date.new(2025, 1, 6), Date.new(2025, 1, 7), :approved)
      cell = cells_for(emp1)[Date.new(2025, 1, 6)]
      expect(cell.status).to eq("approved")
      expect(cell.leave_code).to eq(casual.code)
    end

    it "marks pending leave days" do
      make_leave(emp2, Date.new(2025, 1, 9), Date.new(2025, 1, 9), :pending)
      expect(cells_for(emp2)[Date.new(2025, 1, 9)].status).to eq("pending")
    end

    it "excludes rejected and cancelled leaves" do
      make_leave(emp1, Date.new(2025, 1, 6), Date.new(2025, 1, 6), :rejected)
      make_leave(emp1, Date.new(2025, 1, 7), Date.new(2025, 1, 7), :cancelled)
      expect(cells_for(emp1)[Date.new(2025, 1, 6)]).to be_nil
      expect(cells_for(emp1)[Date.new(2025, 1, 7)]).to be_nil
    end

    it "lets approved take precedence over an overlapping pending request" do
      make_leave(emp1, Date.new(2025, 1, 6), Date.new(2025, 1, 6), :pending)
      make_leave(emp1, Date.new(2025, 1, 6), Date.new(2025, 1, 6), :approved)
      expect(cells_for(emp1)[Date.new(2025, 1, 6)].status).to eq("approved")
    end

    it "clips leaves that span the month boundary to the visible month" do
      make_leave(emp1, Date.new(2024, 12, 30), Date.new(2025, 1, 2), :approved)
      cells = cells_for(emp1)
      expect(cells[Date.new(2025, 1, 1)]).not_to be_nil
      expect(cells[Date.new(2024, 12, 31)]).to be_nil
    end
  end

  describe "#empty?" do
    it "is true when there are no employees" do
      empty = described_class.new(employees: [], month: 1, year: 2025, tenant: tenant)
      expect(empty).to be_empty
    end
  end
end
