class AnnouncementRead < ApplicationRecord
  acts_as_tenant :tenant
  belongs_to :tenant
  belongs_to :announcement
  belongs_to :employee

  validates :read_at, presence: true
  validates :employee_id, uniqueness: { scope: :announcement_id }
end
