require "rails_helper"

RSpec.describe PayrollRunPresenter do
  let(:payroll_run) { build(:payroll_run, status: "approved", total_net_pay: 123456) }
  let(:presenter)   { described_class.new(payroll_run) }

  describe "delegation" do
    it "forwards unknown methods to the wrapped record" do
      expect(presenter.period_label).to eq(payroll_run.period_label)
    end

    it "exposes the underlying record via #model" do
      expect(presenter.model).to be(payroll_run)
    end
  end

  describe "status badge" do
    it "returns the configured label and classes for a known status" do
      expect(presenter.status_badge_label).to eq("Approved")
      expect(presenter.status_badge_classes).to eq("bg-green-100 text-green-700")
    end

    it "falls back to a titleized label and default classes for an unknown status" do
      run = described_class.new(build(:payroll_run).tap { |r| allow(r).to receive(:status).and_return("queued") })
      expect(run.status_badge_label).to eq("Queued")
      expect(run.status_badge_classes).to eq("bg-gray-100 text-gray-600")
    end
  end

  describe "currency formatting" do
    it "formats net pay with the rupee symbol and delimiters" do
      expect(presenter.formatted_total_net_pay).to eq("₹123,456")
    end

    it "#money rounds and formats any value" do
      expect(presenter.money(9999.6)).to eq("₹10,000")
    end
  end

  describe ".wrap" do
    it "wraps every element of a collection" do
      wrapped = described_class.wrap([ payroll_run ])
      expect(wrapped).to all(be_a(described_class))
    end
  end
end
