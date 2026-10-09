# Operability for background payroll work:
# - processing_errors: the employees a run skipped and why, kept on the run so
#   HR can see them on the run page (previously only emailed/logged).
# - processing_failure: why the last processing attempt gave up; the run goes
#   back to draft instead of staying in "processing" forever.
# - job_dispatches.failed_at: a dispatch that was delivered too many times
#   without completing stops being redelivered every five minutes.
class AddFailureTrackingToPayrollAndDispatches < ActiveRecord::Migration[8.1]
  def change
    add_column :payroll_runs, :processing_errors, :jsonb, default: [], null: false
    add_column :payroll_runs, :processing_failure, :text
    add_column :job_dispatches, :failed_at, :datetime
  end
end
