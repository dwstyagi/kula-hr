require "rails_helper"

RSpec.describe Payroll::ReadinessCheck do
  let(:tenant)    { create(:tenant) }
  let(:month)     { 5 }
  let(:year)      { 2026 }
  let(:structure) { create(:salary_structure, tenant: tenant) }

  def lock_attendance(employee)
    create(:attendance_summary, :locked, tenant: tenant, employee: employee, month: month, year: year)
  end

  def assign_salary(employee)
    create(:employee_salary, tenant: tenant, employee: employee, salary_structure: structure)
  end

  subject(:result) { described_class.new(month: month, year: year, tenant: tenant).call }

  around { |ex| ActsAsTenant.with_tenant(tenant) { ex.run } }

  describe "eligibility" do
    it "includes active and probation employees" do
      active    = create(:employee, tenant: tenant)
      probation = create(:employee, :probation, tenant: tenant)

      expect(result.statuses.map(&:employee)).to contain_exactly(active, probation)
    end

    it "excludes resigned employees with no last working day this month" do
      create(:employee, :resigned, tenant: tenant, last_working_date: nil)
      expect(result.eligible_count).to eq(0)
    end

    it "includes resigned employees whose last working day falls in the month" do
      leaver = create(:employee, :resigned, tenant: tenant,
                      last_working_date: Date.new(year, month, 15))
      expect(result.statuses.map(&:employee)).to include(leaver)
    end
  end

  describe "classification" do
    it "marks an employee with locked attendance and a salary as ready" do
      emp = create(:employee, tenant: tenant)
      lock_attendance(emp)
      assign_salary(emp)

      expect(result.ready.map(&:employee)).to eq([ emp ])
      expect(result.will_skip).to be_empty
      expect(result.blocking).to be_empty
      expect(result).to be_can_create
    end

    it "treats an active employee without locked attendance as a hard blocker" do
      emp = create(:employee, tenant: tenant)
      assign_salary(emp) # has salary, but no locked attendance

      expect(result.blocking.map(&:employee)).to eq([ emp ])
      expect(result).not_to be_can_create
      # blockers are not also listed as will_skip
      expect(result.will_skip).to be_empty
    end

    it "treats an active employee with attendance but no salary as a will-skip (not a blocker)" do
      emp = create(:employee, tenant: tenant)
      lock_attendance(emp)

      expect(result).to be_can_create
      expect(result.will_skip.map(&:employee)).to eq([ emp ])
      skip = result.will_skip.first
      expect(skip.reasons).to eq([ "no salary assigned" ])
    end

    it "treats a resigned leaver with no attendance as a will-skip, not a blocker" do
      leaver = create(:employee, :resigned, tenant: tenant,
                      last_working_date: Date.new(year, month, 10))
      assign_salary(leaver)

      expect(result).to be_can_create # resigned w/o attendance does not block
      expect(result.will_skip.map(&:employee)).to eq([ leaver ])
      expect(result.will_skip.first.reasons).to eq([ "no locked attendance" ])
    end

    it "lists both reasons when an employee is missing attendance and salary" do
      emp = create(:employee, :probation, tenant: tenant) # no attendance, no salary
      expect(result.blocking.map(&:employee)).to eq([ emp ]) # probation blocks on attendance
      expect(result.blocking.first.reasons).to contain_exactly("no locked attendance", "no salary assigned")
    end
  end

  describe "#can_create?" do
    it "is false while any active/probation employee lacks locked attendance" do
      ready = create(:employee, tenant: tenant)
      lock_attendance(ready); assign_salary(ready)
      create(:employee, tenant: tenant) # blocker

      expect(result).not_to be_can_create
    end

    it "is true once every active/probation employee has locked attendance" do
      emp = create(:employee, tenant: tenant)
      lock_attendance(emp) # salary missing is fine for creation

      expect(result).to be_can_create
    end
  end
end
