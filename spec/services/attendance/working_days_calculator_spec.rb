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

    context "with active holidays in the month" do
      it "subtracts holidays that fall on a working day" do
        # Jan 1 & Jan 15, 2025 are both weekdays (Wed/Wed) → 2 fewer working days
        create(:holiday, tenant: tenant, date: Date.new(2025, 1, 1))
        create(:holiday, tenant: tenant, date: Date.new(2025, 1, 15))
        expect(calculator("all_saturdays_sundays").call).to eq(21)
      end

      it "does not double-count a holiday that falls on a week-off" do
        # Jan 4, 2025 is a Saturday — already excluded as a week-off
        create(:holiday, tenant: tenant, date: Date.new(2025, 1, 4))
        expect(calculator("all_saturdays_sundays").call).to eq(23)
      end

      it "ignores inactive holidays" do
        create(:holiday, :inactive, tenant: tenant, date: Date.new(2025, 1, 1))
        expect(calculator("all_saturdays_sundays").call).to eq(23)
      end

      it "ignores holidays belonging to another tenant" do
        other_tenant = create(:tenant)
        create(:holiday, tenant: other_tenant, date: Date.new(2025, 1, 1))
        expect(calculator("all_saturdays_sundays").call).to eq(23)
      end
    end

    context "with location-based holidays" do
      let(:mumbai) { create(:work_location, tenant: tenant, name: "Mumbai") }
      let(:bengaluru) { create(:work_location, tenant: tenant, name: "Bengaluru") }

      before do
        payroll_setting.update!(week_off_pattern: "all_saturdays_sundays")
        # Jan 1 (Wed): company-wide; Jan 15 (Wed): Mumbai-only; Jan 16 (Thu): Bengaluru-only
        create(:holiday, tenant: tenant, date: Date.new(2025, 1, 1), work_location: nil)
        create(:holiday, tenant: tenant, date: Date.new(2025, 1, 15), work_location: mumbai)
        create(:holiday, tenant: tenant, date: Date.new(2025, 1, 16), work_location: bengaluru)
      end

      def location_calculator(location)
        described_class.new(month: 1, year: 2025, tenant: tenant, work_location: location)
      end

      it "subtracts company-wide holidays only when no location given" do
        # 23 working - Jan 1 = 22
        expect(location_calculator(nil).call).to eq(22)
      end

      it "subtracts company-wide + Mumbai holidays for a Mumbai employee" do
        # 23 - Jan 1 - Jan 15 = 21
        expect(location_calculator(mumbai).call).to eq(21)
      end

      it "subtracts company-wide + Bengaluru holidays for a Bengaluru employee" do
        # 23 - Jan 1 - Jan 16 = 21
        expect(location_calculator(bengaluru).call).to eq(21)
      end

      it "does not subtract another location's holiday" do
        # Mumbai employee should NOT lose Jan 16 (Bengaluru-only)
        expect(location_calculator(mumbai).call).not_to eq(20)
      end

      it "accepts a work_location id as well as a record" do
        expect(location_calculator(mumbai.id).call).to eq(21)
      end
    end
  end
end
