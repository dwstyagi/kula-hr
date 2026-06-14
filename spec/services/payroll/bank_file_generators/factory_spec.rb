require "rails_helper"

RSpec.describe Payroll::BankFileGenerators::Factory do
  let(:payroll_run) { create(:payroll_run) }

  describe ".for" do
    it "returns the matching generator for a known bank" do
      expect(described_class.for("hdfc", payroll_run: payroll_run)).to be_a(Payroll::BankFileGenerators::Hdfc)
      expect(described_class.for("icici", payroll_run: payroll_run)).to be_a(Payroll::BankFileGenerators::Icici)
      expect(described_class.for("sbi", payroll_run: payroll_run)).to be_a(Payroll::BankFileGenerators::Sbi)
      expect(described_class.for("generic_csv", payroll_run: payroll_run)).to be_a(Payroll::BankFileGenerators::GenericCsv)
    end

    it "falls back to GenericCsv for blank or unknown banks" do
      expect(described_class.for(nil, payroll_run: payroll_run)).to be_a(Payroll::BankFileGenerators::GenericCsv)
      expect(described_class.for("", payroll_run: payroll_run)).to be_a(Payroll::BankFileGenerators::GenericCsv)
      expect(described_class.for("unknown", payroll_run: payroll_run)).to be_a(Payroll::BankFileGenerators::GenericCsv)
    end
  end

  describe ".file_meta" do
    it "returns csv metadata for generic_csv (and blank default)" do
      expect(described_class.file_meta("generic_csv")).to eq([ "csv", "text/csv" ])
      expect(described_class.file_meta(nil)).to eq([ "csv", "text/csv" ])
    end

    it "returns txt metadata for bank-specific formats" do
      expect(described_class.file_meta("hdfc")).to eq([ "txt", "text/plain" ])
      expect(described_class.file_meta("icici")).to eq([ "txt", "text/plain" ])
      expect(described_class.file_meta("sbi")).to eq([ "txt", "text/plain" ])
    end
  end

  describe ".supported_banks" do
    it "lists all registered bank keys" do
      expect(described_class.supported_banks).to contain_exactly("hdfc", "icici", "sbi", "generic_csv")
    end
  end
end
