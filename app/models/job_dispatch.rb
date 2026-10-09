# Database-backed outbox. Rows survive Redis outages and worker termination.
class JobDispatch < ApplicationRecord
  JOBS = %w[PayrollProcessingJob BackgroundTaskJob BulkPayslipPdfJob].freeze
  # Deliveries that reached the queue but never completed (worker killed,
  # job lost). Failed enqueues do not count, so a Redis outage alone never
  # exhausts a dispatch.
  MAX_DELIVERIES = 5

  scope :pending, -> { where(failed_at: nil) }
  validates :job_class, inclusion: { in: JOBS }
  after_create_commit :deliver

  def self.enqueue!(job, *arguments)
    scope = where(job_class: job.name).where("arguments = ?::jsonb", arguments.to_json)
    # A dispatch that was given up on must not block the same work being
    # requested again (e.g. HR clicking Process after a failure).
    scope.where.not(failed_at: nil).delete_all
    scope.first || transaction(requires_new: true) { create!(job_class: job.name, arguments: arguments) }
  rescue ActiveRecord::RecordNotUnique
    scope.first!
  end

  def deliver
    reload
    return give_up! if attempts >= MAX_DELIVERIES

    # Lease the dispatch briefly, never holding a database lock during Redis I/O.
    claimed = self.class.pending.where(id: id).where("dispatched_at IS NULL OR dispatched_at < ?", 5.minutes.ago)
      .update_all([ "dispatched_at = ?, attempts = attempts + 1", Time.current ])
    return if claimed.zero?
    job = job_class.constantize.perform_later(*arguments, dispatch_id: id)
    raise ActiveJob::EnqueueError, "Queue rejected job" unless job && job.successfully_enqueued?
  rescue StandardError => error
    self.class.where(id: id).update_all([ "dispatched_at = NULL, attempts = GREATEST(attempts - 1, 0), last_error = ?",
                                          "#{error.class}: #{error.message}".truncate(1000) ])
    Rails.logger.error("Job dispatch #{id} failed: #{error.class}")
    false
  end

  def self.recover
    pending.where("dispatched_at IS NULL OR dispatched_at < ?", 5.minutes.ago).find_each(batch_size: 100, &:deliver)
  end

  # Stop redelivering. The row stays (failed_at set) as the record of what was
  # lost; a payroll run waiting on it goes back to draft with the reason.
  def give_up!
    return if failed_at

    reason = "Background job #{job_class} was delivered #{attempts} times without completing" \
             "#{" (last error: #{last_error})" if last_error.present?}"
    # A long payroll run is still being worked on: keep the dispatch.
    if job_class == "PayrollProcessingJob" && PayrollProcessingJob.give_up(arguments.first, reason) == :running
      return false
    end

    update_columns(failed_at: Time.current)
    Rails.logger.error("[JobDispatch] #{id} gave up: #{reason}")
    false
  end
end
