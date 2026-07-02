require "rails_helper"

RSpec.describe Announcement, type: :model do
  let(:tenant) { create(:tenant) }

  before { set_tenant(tenant) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:title) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:tenant).optional }
    it { is_expected.to belong_to(:author).class_name("User") }
    it { is_expected.to have_many(:announcement_reads).dependent(:destroy) }
  end

  describe "scopes" do
    let!(:published) { create(:announcement, :published, tenant: tenant) }
    let!(:draft)     { create(:announcement, tenant: tenant) }

    it ".published returns only published announcements" do
      expect(Announcement.published).to include(published)
      expect(Announcement.published).not_to include(draft)
    end
  end

  describe "#publish!" do
    it "marks published and stamps published_at once" do
      announcement = create(:announcement, tenant: tenant)
      announcement.publish!
      expect(announcement.published).to be true
      first_stamp = announcement.published_at
      expect(first_stamp).to be_present

      announcement.publish!
      expect(announcement.published_at).to eq(first_stamp)
    end
  end

  describe "#notify_readers_of_update!" do
    let(:announcement) { create(:announcement, :published, tenant: tenant) }
    let(:employee)     { create(:employee, tenant: tenant) }

    before { announcement.mark_read_by!(employee) }

    it "clears existing read receipts and stamps last_edited_at" do
      expect {
        announcement.notify_readers_of_update!
      }.to change { announcement.announcement_reads.count }.from(1).to(0)

      expect(announcement.last_edited_at).to be_present
      expect(announcement.edited?).to be true
    end
  end

  describe "read tracking" do
    let(:announcement) { create(:announcement, :published, tenant: tenant) }
    let(:employee)     { create(:employee, tenant: tenant) }

    it "#mark_read_by! records a read once (idempotent)" do
      expect {
        announcement.mark_read_by!(employee)
        announcement.mark_read_by!(employee)
      }.to change { announcement.announcement_reads.count }.by(1)
    end

    it "#read_by? reflects whether the employee has read it" do
      expect(announcement.read_by?(employee)).to be false
      announcement.mark_read_by!(employee)
      expect(announcement.read_by?(employee)).to be true
    end
  end
end
