class RecoverJobDispatchesJob < ApplicationJob
  queue_as :scheduled
  def perform
    JobDispatch.recover
    Payroll::PayslipArchive.cleanup
  end
end
