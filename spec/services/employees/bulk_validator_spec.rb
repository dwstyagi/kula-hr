require "rails_helper"

RSpec.describe Employees::BulkValidator do
  let(:tenant) { create(:tenant) }

  def make_row(overrides = {})
    {
      "_row"              => 2,
      "first_name"        => "Jane",
      "last_name"         => "Doe",
      "email"             => "jane@example.com",
      "joining_date"      => "15/08/2023",
      "employment_status" => "active"
    }.merge(overrides)
  end

  subject(:result) { described_class.new(rows, tenant: tenant).call }

  context "with all valid rows" do
    let(:rows) { [ make_row, make_row("email" => "john@example.com", "_row" => 3) ] }

    it "marks all rows as valid" do
      expect(result[:valid_rows].size).to eq(2)
      expect(result[:invalid_rows]).to be_empty
    end

    it "returns validated_rows with _valid and _errors keys" do
      result[:validated_rows].each do |row|
        expect(row).to have_key("_valid")
        expect(row).to have_key("_errors")
      end
    end
  end

  context "with a row that has a validation error" do
    let(:rows) { [ make_row("email" => "bad-email") ] }

    it "marks the row as invalid" do
      expect(result[:invalid_rows].size).to eq(1)
      expect(result[:invalid_rows].first["_errors"]).to include("Email is not valid")
    end
  end

  describe "duplicate email within the file" do
    let(:rows) do
      [
        make_row("email" => "same@example.com", "_row" => 2),
        make_row("email" => "same@example.com", "_row" => 3)
      ]
    end

    it "flags the second occurrence as a duplicate" do
      invalid = result[:invalid_rows]
      expect(invalid.size).to eq(1)
      expect(invalid.first["_errors"]).to include(match(/Duplicate email in file.*row 2/i))
    end

    it "keeps the first occurrence valid" do
      expect(result[:valid_rows].first["email"]).to eq("same@example.com")
    end
  end

  describe "email already in the database" do
    before do
      ActsAsTenant.with_tenant(tenant) do
        create(:employee, email: "existing@example.com")
      end
    end

    let(:rows) { [ make_row("email" => "existing@example.com") ] }

    it "marks the row invalid with an existence error" do
      expect(result[:invalid_rows].size).to eq(1)
      expect(result[:invalid_rows].first["_errors"]).to include("Email already exists in the system")
    end
  end

  describe "email case insensitivity" do
    before do
      ActsAsTenant.with_tenant(tenant) do
        create(:employee, email: "user@example.com")
      end
    end

    let(:rows) { [ make_row("email" => "USER@EXAMPLE.COM") ] }

    it "detects the duplicate regardless of case" do
      expect(result[:invalid_rows].size).to eq(1)
    end
  end

  describe "tenant isolation" do
    let(:other_tenant) { create(:tenant) }

    before do
      ActsAsTenant.with_tenant(other_tenant) do
        create(:employee, email: "shared@example.com")
      end
    end

    let(:rows) { [ make_row("email" => "shared@example.com") ] }

    it "does not flag emails from other tenants as duplicates" do
      expect(result[:valid_rows].size).to eq(1)
    end
  end
end
