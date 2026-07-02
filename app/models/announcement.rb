class Announcement < ApplicationRecord
  acts_as_tenant :tenant
  belongs_to :tenant
  belongs_to :author, class_name: "User"

  has_many :announcement_reads, dependent: :destroy
  has_many :readers, through: :announcement_reads, source: :employee

  validates :title, presence: true

  scope :published,    -> { where(published: true) }
  scope :recent_first, -> { order(Arel.sql("COALESCE(published_at, created_at) DESC")) }

  # Publish (idempotent): stamps published_at only on the first publish.
  def publish!
    update!(published: true, published_at: published_at || Time.current)
  end

  # Whether this announcement has been edited-and-notified since it was published.
  def edited?
    last_edited_at.present?
  end

  # Marks the announcement as updated and clears existing read receipts so it
  # re-surfaces as unread for everyone who had already read it.
  def notify_readers_of_update!
    transaction do
      update!(last_edited_at: Time.current)
      announcement_reads.delete_all
    end
  end

  def read_by?(employee)
    announcement_reads.exists?(employee_id: employee.id)
  end

  # Records that an employee has seen this announcement. Idempotent.
  def mark_read_by!(employee)
    announcement_reads.find_or_create_by!(employee: employee) do |r|
      r.read_at = Time.current
    end
  end
end
