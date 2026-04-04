class PayrollProcessingJob < ApplicationJob
  queue_as :payroll

  # Only retry once — if processing fails twice, HR should investigate
  # and use the Reprocess button rather than having Sidekiq silently retry
  retry_on StandardError, attempts: 2, wait: 30.seconds

  def perform(payroll_run_id)
    payroll_run = PayrollRun.find(payroll_run_id)
    return unless payroll_run.processing?

    # Scope all queries to the correct tenant for this run
    ActsAsTenant.with_tenant(payroll_run.tenant) do
      result = Payroll::PayrollProcessor.new(payroll_run: payroll_run).call

      if result.errors.any?
        PayrollMailer.processing_complete_with_errors(payroll_run, result.errors).deliver_later
      else
        PayrollMailer.processing_complete(payroll_run).deliver_later
      end
    end
  end
end
