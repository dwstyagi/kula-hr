require "rails_helper"

RSpec.describe Attendance::WorkingDaysCalculator do
  # January 2025: 31 days, 4 Saturdays (4,11,18,25), 4 Sundays (5,12,19,26)
  let(:tenant)          { create(:tenant) }
  let(:payroll_setting) { create(:payroll_setting, tenant: tenant) }

  def calculator(pattern)
    payroll_setting.update!(week_off_pattern: pattern)
    described_class.new(month: 1, year: 2025, tenant: tenant)
  end

  describe "#call" do
    context "all_saturdays_sundays pattern" do
      it "excludes all Saturdays and Sundays" do
        # 31 days - 4 Saturdays - 4 Sundays = 23
        expect(calculator("all_saturdays_sundays").call).to eq(23)
      end
    end

    context "alternate_saturdays_sundays pattern" do
      it "excludes all Sundays and odd-week Saturdays (1st, 3rd)" do
        # Jan 2025: 4 Sundays + Jan 4 (wk1, off) + Jan 18 (wk3, off) = 6 off days → 25 working
        expect(calculator("alternate_saturdays_sundays").call).to eq(25)
      end
    end

    context "only_sundays pattern" do
      it "excludes only Sundays" do
        # 31 days - 4 Sundays = 27
        expect(calculator("only_sundays").call).to eq(27)
      end
    end

    context "with nil payroll_setting" do
      it "defaults to all_saturdays_sundays" do
        tenant_no_setting = create(:tenant)
        calc = described_class.new(month: 1, year: 2025, tenant: tenant_no_setting)
        expect(calc.call).to eq(23)
      end
    end
  end
end
