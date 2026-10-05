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
end
