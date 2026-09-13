# Database-backed outbox. Rows survive Redis outages and worker termination.
class JobDispatch < ApplicationRecord
  JOBS = %w[PayrollProcessingJob BackgroundTaskJob BulkPayslipPdfJob].freeze
  validates :job_class, inclusion: { in: JOBS }
  after_create_commit :deliver

  def self.enqueue!(job, *arguments)
    scope = where(job_class: job.name).where("arguments = ?::jsonb", arguments.to_json)
    scope.first || transaction(requires_new: true) { create!(job_class: job.name, arguments: arguments) }
  rescue ActiveRecord::RecordNotUnique
    scope.first!
  end

  def deliver
    # Lease the dispatch briefly, never holding a database lock during Redis I/O.
    claimed = self.class.where(id: id).where("dispatched_at IS NULL OR dispatched_at < ?", 5.minutes.ago)
      .update_all([ "dispatched_at = ?, attempts = attempts + 1", Time.current ])
    return if claimed.zero?
    job = job_class.constantize.perform_later(*arguments, dispatch_id: id)
    raise ActiveJob::EnqueueError, "Queue rejected job" unless job && job.successfully_enqueued?
  rescue StandardError => error
    self.class.where(id: id).update_all(dispatched_at: nil, last_error: "#{error.class}: #{error.message}".truncate(1000))
    Rails.logger.error("Job dispatch #{id} failed: #{error.class}")
    false
  end

  def self.recover
    where("dispatched_at IS NULL OR dispatched_at < ?", 5.minutes.ago).find_each(batch_size: 100, &:deliver)
  end
end
