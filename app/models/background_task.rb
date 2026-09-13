class BackgroundTask < ApplicationRecord
  acts_as_tenant :tenant
  belongs_to :tenant
  belongs_to :user
  KINDS = %w[attendance attendance_import payroll_reset employee_import].freeze
  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: %w[queued running completed failed] }
  scope :active, -> { where(status: %w[queued running]) }

  def self.enqueue!(tenant:, user:, kind:, task_key:, payload:)
    transaction(requires_new: true) do
      existing = active.find_by(tenant: tenant, kind: kind, task_key: task_key)
      return existing if existing
      task = create!(tenant: tenant, user: user, kind: kind, task_key: task_key, payload: payload)
      JobDispatch.enqueue!(BackgroundTaskJob, task.id)
      task
    end
  rescue ActiveRecord::RecordNotUnique
    active.find_by!(tenant: tenant, kind: kind, task_key: task_key)
  end

  def title
    { "attendance" => "Generate attendance", "attendance_import" => "Import attendance", "payroll_reset" => "Reset payroll", "employee_import" => "Import employees" }.fetch(kind)
  end

  def pending? = status.in?(%w[queued running])
end
