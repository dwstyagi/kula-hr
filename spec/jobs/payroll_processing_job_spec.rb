require "rails_helper"

RSpec.describe PayrollProcessingJob do
  include ActiveJob::TestHelper

  let(:tenant) { create(:tenant, :active) }
  let(:run)    { create(:payroll_run, :processing, tenant: tenant) }

  before { set_tenant(tenant) }

  describe ".give_up" do
    it "returns a processing run to draft, records why and emails HR" do
      expect {
        described_class.give_up(run.id, "PG::ConnectionBad: server closed the connection")
      }.to have_enqueued_mail(PayrollMailer, :processing_failed)
      expect(run.reload).to be_draft
      expect(run.processing_failure).to include("ConnectionBad")
    end

    it "leaves a run alone once it is no longer processing" do
      run.update_columns(status: "processed")
      described_class.give_up(run.id, "late failure")
      expect(run.reload).to be_processed
      expect(run.processing_failure).to be_nil
    end
  end

  it "gives up after its retries instead of leaving the run in processing" do
    allow(Payroll::PayrollProcessor).to receive(:new).and_raise(ActiveRecord::ConnectionNotEstablished, "db down")
    perform_enqueued_jobs(only: described_class) do
      described_class.perform_later(run.id)
    end
    expect(run.reload).to be_draft
    expect(run.processing_failure).to include("db down")
  end

  it "clears the failure when processing starts again" do
    run.update_columns(status: "draft", processing_failure: "earlier failure")
    run.start_processing!
    expect(run.reload.processing_failure).to be_nil
  end
  shared_examples "a retired payroll dispatch" do
    it "discards stale dispatches without calculating monthly salary" do
      run.update_columns(run_type: retired_type)
      payslip = create(:payslip, tenant: tenant, payroll_run: run)
      dispatch = JobDispatch.enqueue!(described_class, run.id)
      expect(Payroll::PayrollProcessor).not_to receive(:new)

      described_class.perform_now(run.id, dispatch_id: dispatch.id)

      expect(run.reload).to be_draft
      expect(run.processing_failure).to include("no longer supported")
      expect(run.payslips).to include(payslip)
      expect(JobDispatch.exists?(dispatch.id)).to be(false)
    end
  end

  %w[bonus additional full_and_final].each do |type|
    context "with a #{type} run" do
      let(:retired_type) { type }
      include_examples "a retired payroll dispatch"
    end
  end
end
