class Holiday < ApplicationRecord
  acts_as_tenant :tenant
  belongs_to :tenant
  # A nil work_location means the holiday is company-wide (applies to every location).
  belongs_to :work_location, optional: true

  validates :name, presence: true
  validates :date, presence: true
  validates :date, uniqueness: { scope: [ :tenant_id, :work_location_id ], message: "already has a holiday on this date" }

  scope :active, -> { where(is_active: true) }
  scope :company_wide, -> { where(work_location_id: nil) }

  # Holidays that apply to a given work location: company-wide holidays plus the
  # location's own holidays. Pass nil to get only company-wide holidays.
  scope :applicable_to, ->(work_location_id) {
    where(work_location_id: [ nil, work_location_id ].uniq)
  }
end
