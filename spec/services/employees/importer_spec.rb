require "rails_helper"

RSpec.describe Employees::Importer do
  let(:tenant) { create(:tenant, :active) }
  before { set_tenant(tenant); create(:payroll_setting, tenant: tenant) }

  def rows(count, prefix: "import")
    count.times.map do |i|
      { "first_name" => "Import", "last_name" => "Person", "email" => "#{prefix}#{i}@example.com",
        "date_of_birth" => "01/01/1990", "joining_date" => "01/04/2026", "employment_status" => "active",
        "department" => "Engineering", "designation" => "Engineer", "_row" => i + 1 }
    end
  end

  def query_count
    count = 0
    callback = ->(*args) { p = args.last; count += 1 unless p[:cached] || p[:name].in?(%w[SCHEMA TRANSACTION]) }
    ActiveRecord::Base.uncached do
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    end
    count
  end

  it "uses a bounded number of queries for model validation and inserts" do
    create(:department, tenant: tenant, name: "Engineering")
    create(:designation, tenant: tenant, name: "Engineer")
    small = query_count { described_class.new(rows: rows(1, prefix: "small"), tenant: tenant).call }
    large = query_count { described_class.new(rows: rows(20), tenant: tenant).call }
    expect(large).to be <= small
    expect(Employee.count).to eq(21)
  end

  it "revalidates duplicates and fields before writing and reports skipped rows" do
    create(:employee, tenant: tenant, email: "IMPORT0@example.com")
    input = rows(3)
    input[1]["pan_number"] = "invalid"
    result = described_class.new(rows: input, tenant: tenant).call
    expect(result[:imported_count]).to eq(1)
    expect(result[:invalid_rows].size).to eq(2)
    expect(Employee.find_by(email: "import2@example.com")).to be_present
  end

  it "allocates leave balances and does not duplicate them on a repeated import" do
    create(:leave_type, :casual, tenant: tenant)
    described_class.new(rows: rows(2), tenant: tenant).call
    expect(LeaveBalance.count).to eq(2)
    result = described_class.new(rows: rows(2), tenant: tenant).call
    expect(result[:imported_count]).to eq(0)
    expect(LeaveBalance.count).to eq(2)
  end
end
