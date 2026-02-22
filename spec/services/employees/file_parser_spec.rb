require "rails_helper"

RSpec.describe Employees::FileParser do
  # Builds a minimal in-memory xlsx file using Axlsx and returns a Tempfile
  def build_xlsx(headers:, rows: [])
    tmpfile = Tempfile.new([ "test_import", ".xlsx" ])
    tmpfile.binmode

    package = Axlsx::Package.new
    package.workbook.add_worksheet(name: "Sheet1") do |sheet|
      sheet.add_row headers
      rows.each { |r| sheet.add_row r }
    end
    package.serialize(tmpfile.path)
    tmpfile
  end

  let(:valid_headers) { Employees::TemplateGenerator::HEADERS }

  let(:valid_rows) do
    [
      [ "Jane", "Doe", "jane@example.com", "9876543210",
        "15/08/1990", "female", "01/06/2023", "active",
        "Engineering", "Software Engineer",
        "ABCDE1234F", "123456789012", "", "",
        "HDFC", "12345678", "HDFC0001234",
        "123 Main St", "Mumbai", "Maharashtra", "400001",
        "John Doe", "9876500000", "Father" ]
    ]
  end

  describe "#call" do
    context "with a valid xlsx file" do
      let(:file) { build_xlsx(headers: valid_headers, rows: valid_rows) }

      subject(:result) { described_class.new(file).call }

      it { expect(result).to be_success }
      it { expect(result.errors).to be_empty }
      it { expect(result.rows.size).to eq(1) }

      it "parses row data correctly" do
        row = result.rows.first
        expect(row["first_name"]).to eq("Jane")
        expect(row["email"]).to eq("jane@example.com")
        expect(row["employment_status"]).to eq("active")
      end

      it "assigns _row numbers starting from 2" do
        expect(result.rows.first["_row"]).to eq(2)
      end

      it "skips completely blank rows" do
        file = build_xlsx(headers: valid_headers, rows: [ valid_rows.first, Array.new(valid_headers.size) ])
        result = described_class.new(file).call
        expect(result.rows.size).to eq(1)
      end
    end

    context "with missing columns" do
      let(:file) { build_xlsx(headers: %w[first_name last_name]) }

      subject(:result) { described_class.new(file).call }

      it { expect(result).not_to be_success }
      it { expect(result.errors.first).to match(/Missing columns/i) }
    end

    context "with an invalid file" do
      let(:bad_file) do
        tmp = Tempfile.new([ "bad", ".xlsx" ])
        tmp.write("this is not xlsx content")
        tmp.flush
        tmp
      end

      subject(:result) { described_class.new(bad_file).call }

      it { expect(result).not_to be_success }
      it { expect(result.errors.first).to match(/Invalid file|Could not read/i) }
    end
  end
end
