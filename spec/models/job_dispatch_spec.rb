require "rails_helper"

RSpec.describe JobDispatch do
  let(:tenant) { create(:tenant, :active) }
  before { set_tenant(tenant) }

  it "does not count failed enqueues toward the delivery limit" do
    allow(BackgroundTaskJob).to receive(:perform_later).and_raise(ActiveJob::EnqueueError, "offline")
    dispatch = JobDispatch.enqueue!(BackgroundTaskJob, 1)
    10.times { dispatch.reload.deliver }
    expect(dispatch.reload.attempts).to eq(0)
    expect(dispatch.failed_at).to be_nil
  end

  it "gives up after too many deliveries that never completed" do
    dispatch = JobDispatch.enqueue!(BackgroundTaskJob, 2)
    dispatch.update_columns(attempts: JobDispatch::MAX_DELIVERIES, dispatched_at: 10.minutes.ago)
    expect { JobDispatch.recover }.not_to have_enqueued_job(BackgroundTaskJob)
    expect(dispatch.reload.failed_at).to be_present
    expect { JobDispatch.recover }.not_to change { dispatch.reload.attempts }
  end

  it "lets the same work be requested again after giving up" do
    dispatch = JobDispatch.enqueue!(BackgroundTaskJob, 3)
    dispatch.update_columns(failed_at: Time.current)
    expect(JobDispatch.enqueue!(BackgroundTaskJob, 3).id).not_to eq(dispatch.id)
  end

  describe "a payroll dispatch that gives up" do
    let(:run) { create(:payroll_run, :processing, tenant: tenant) }

    it "returns the run to draft with the reason" do
      allow(PayrollProcessingJob).to receive(:perform_later).and_return(double(successfully_enqueued?: true))
      dispatch = JobDispatch.enqueue!(PayrollProcessingJob, run.id)
      dispatch.update_columns(attempts: JobDispatch::MAX_DELIVERIES, dispatched_at: 10.minutes.ago)
      JobDispatch.recover
      expect(run.reload).to be_draft
      expect(run.processing_failure).to include("delivered")
      expect(dispatch.reload.failed_at).to be_present
    end
  end
end
