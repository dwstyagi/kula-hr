class PayrollProcessingJob < ApplicationJob
  self.enqueue_after_transaction_commit = true
  queue_as :payroll

  # After the last retry the run goes back to draft with the reason shown on
  # the run page and HR is emailed, instead of staying in "processing" with
  # the dispatch redelivered every five minutes.
  retry_on StandardError, attempts: 2, wait: 30.seconds do |job, error|
    run_id, options = job.arguments
    PayrollProcessingJob.give_up(run_id, "#{error.class.name}: #{error.message}")
    JobDispatch.where(id: options[:dispatch_id]).delete_all if options.is_a?(Hash) && options[:dispatch_id]
  end

  def perform(payroll_run_id, dispatch_id: nil)
    Payroll::RunLock.with(payroll_run_id) do
      run = ActsAsTenant.without_tenant { PayrollRun.find_by(id: payroll_run_id) }
      unless run
        JobDispatch.where(id: dispatch_id).delete_all
        return
      end
      ActsAsTenant.with_tenant(run.tenant) do
        if run.processing?
          processor = if run.full_and_final?
            Payroll::FullAndFinalPayrollProcessor
          elsif run.off_cycle?
            Payroll::OffCyclePayrollProcessor
          else
            Payroll::PayrollProcessor
          end
          result = processor.new(payroll_run: run).call
          if result.errors.any?
            PayrollMailer.processing_complete_with_errors(run, result.errors).deliver_later
          else
            PayrollMailer.processing_complete(run).deliver_later
          end
        end
        JobDispatch.where(id: dispatch_id).delete_all
      end
    end
  end

  # Return a run stuck in processing to draft, record why, and tell HR.
  # Payslips already created are kept; processing again resumes the rest.
  # Returns :running (and changes nothing) while a worker still holds the run.
  def self.give_up(payroll_run_id, reason)
    run = ActsAsTenant.without_tenant { PayrollRun.find_by(id: payroll_run_id) }
    return :missing unless run

    abandoned = nil
    held = Payroll::RunLock.with(run.id) do
      ActsAsTenant.with_tenant(run.tenant) do
        abandoned = run.with_lock do
          next false unless run.processing?

          run.update!(processing_failure: reason.to_s.truncate(1000))
          run.abandon_processing!
          true
        end
      end
    end
    return :running unless held

    if abandoned
      Rails.logger.error("[PayrollProcessingJob] run=#{run.id} gave up: #{reason}")
      PayrollMailer.processing_failed(run, reason.to_s.truncate(500)).deliver_later
    end
    :abandoned
  end
end
