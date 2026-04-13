require "rails_helper"

RSpec.describe Holiday, type: :model do
  let(:tenant) { create(:tenant) }

  before { set_tenant(tenant) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:date) }

    describe "date uniqueness per tenant" do
      let(:fixed_date) { Date.new(2026, 8, 15) }

      before { create(:holiday, tenant: tenant, date: fixed_date, name: "Independence Day") }

      it "rejects a duplicate date within the same tenant" do
        duplicate = build(:holiday, tenant: tenant, date: fixed_date, name: "Another Holiday")
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:date]).to include(match(/already has a holiday/))
      end

      it "allows the same date for a different tenant" do
        other = create(:tenant)
        ActsAsTenant.with_tenant(other) do
          expect(build(:holiday, tenant: other, date: fixed_date)).to be_valid
        end
      end
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:tenant).optional }
  end

  describe "scopes" do
    let!(:active_holiday)   { create(:holiday, tenant: tenant, is_active: true,  date: Date.today + 10) }
    let!(:inactive_holiday) { create(:holiday, tenant: tenant, is_active: false, date: Date.today + 20) }

    it ".active returns only active holidays" do
      expect(Holiday.active).to include(active_holiday)
      expect(Holiday.active).not_to include(inactive_holiday)
    end
  end
end
