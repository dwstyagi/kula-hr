class PayrollProcessingJob < ApplicationJob
  self.enqueue_after_transaction_commit = true
  queue_as :payroll
  retry_on StandardError, attempts: 2, wait: 30.seconds

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
end
