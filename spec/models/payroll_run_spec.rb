require "rails_helper"

RSpec.describe PayrollRun, type: :model do
  let(:tenant)  { create(:tenant) }
  let(:hr_user) { create(:user, :hr_admin) }

  before { set_tenant(tenant) }

  subject { build(:payroll_run, tenant: tenant, initiated_by: hr_user) }

  # ── Associations ─────────────────────────────────────────────────────────

  describe "associations" do
    it { is_expected.to belong_to(:tenant).optional }
    it { is_expected.to belong_to(:initiated_by).class_name("User") }
    it { is_expected.to belong_to(:approved_by).class_name("User").optional }
    it { is_expected.to have_many(:payslips).dependent(:destroy) }
  end

  # ── Validations ───────────────────────────────────────────────────────────

  describe "validations" do
    it { is_expected.to validate_presence_of(:month) }
    it { is_expected.to validate_presence_of(:year) }
    it { is_expected.to validate_inclusion_of(:month).in_range(1..12) }

    describe "uniqueness of month+year per tenant" do
      before { create(:payroll_run, tenant: tenant, initiated_by: hr_user, month: 3, year: 2026) }

      it "rejects a duplicate month/year for the same tenant" do
        dup = build(:payroll_run, tenant: tenant, initiated_by: hr_user, month: 3, year: 2026)
        dup.valid?
        expect(dup.errors[:month]).not_to be_empty
      end

      it "allows same month/year for a different tenant" do
        other_tenant = create(:tenant)
        dup = build(:payroll_run, tenant: other_tenant, initiated_by: hr_user, month: 3, year: 2026)
        # Switch tenant context so the uniqueness check queries other_tenant's scope
        ActsAsTenant.with_tenant(other_tenant) { expect(dup).to be_valid }
      end
    end
  end

  # ── attendance_must_be_locked validation ─────────────────────────────────

  describe "#attendance_must_be_locked (on: :create)" do
    context "when all eligible employees have locked attendance" do
      it "adds no error" do
        emp = create(:employee, tenant: tenant, employment_status: "active")
        create(:attendance_summary, :locked, tenant: tenant, employee: emp, month: 1, year: 2026)

        run = PayrollRun.new(tenant: tenant, initiated_by: hr_user, month: 1, year: 2026)
        run.validate
        expect(run.errors[:base]).to be_empty
      end
    end

    context "when no employees exist (clean slate)" do
      it "passes validation (0 of 0 locked is fine)" do
        run = PayrollRun.new(tenant: tenant, initiated_by: hr_user, month: 1, year: 2026)
        run.validate
        expect(run.errors[:base]).to be_empty
      end
    end

    context "when an eligible employee has no locked attendance" do
      it "adds a base error referencing the count" do
        create(:employee, tenant: tenant, employment_status: "active")
        # No attendance summary created for this employee

        run = PayrollRun.new(tenant: tenant, initiated_by: hr_user, month: 1, year: 2026)
        run.validate
        expect(run.errors[:base]).not_to be_empty
        expect(run.errors[:base].first).to match(/Attendance not locked/)
      end
    end

    context "when attendance is draft (not locked)" do
      it "adds a base error" do
        emp = create(:employee, tenant: tenant, employment_status: "active")
        create(:attendance_summary, tenant: tenant, employee: emp, month: 1, year: 2026, status: :draft)

        run = PayrollRun.new(tenant: tenant, initiated_by: hr_user, month: 1, year: 2026)
        run.validate
        expect(run.errors[:base]).not_to be_empty
      end
    end
  end

  # ── AASM State Machine ────────────────────────────────────────────────────

  describe "AASM state machine" do
    let(:run) { create(:payroll_run, tenant: tenant, initiated_by: hr_user) }

    it "starts in draft state" do
      expect(run).to be_draft
    end

    it "transitions draft → processing via start_processing!" do
      expect { run.start_processing! }
        .to change { run.status }.from("draft").to("processing")
    end

    it "transitions processing → processed via finish_processing!" do
      run.update_column(:status, "processing")
      expect { run.finish_processing! }.to change { run.status }.to("processed")
    end

    it "transitions processed → under_review via submit_for_review!" do
      run.update_column(:status, "processed")
      expect { run.submit_for_review! }.to change { run.status }.to("under_review")
    end

    it "transitions under_review → approved via approve!" do
      run.update_column(:status, "under_review")
      expect { run.approve! }.to change { run.status }.to("approved")
    end

    it "transitions under_review → rejected via reject!" do
      run.update_column(:status, "under_review")
      expect { run.reject! }.to change { run.status }.to("rejected")
    end

    it "transitions rejected → under_review via resubmit_for_review!" do
      run.update_column(:status, "rejected")
      expect { run.resubmit_for_review! }.to change { run.status }.to("under_review")
    end

    it "transitions approved → paid via mark_paid!" do
      run.update_column(:status, "approved")
      expect { run.mark_paid! }.to change { run.status }.to("paid")
    end

    it "cannot process from under_review" do
      run.update_column(:status, "under_review")
      expect { run.start_processing! }.to raise_error(AASM::InvalidTransition)
    end

    describe "reprocess event" do
      it "resets processed → draft and destroys all payslips" do
        run.update_column(:status, "processed")
        emp = create(:employee, tenant: tenant)
        create(:payslip, tenant: tenant, payroll_run: run, employee: emp)

        run.reprocess!

        expect(run).to be_draft
        expect(run.payslips.count).to eq(0)
        expect(run.total_gross).to eq(0)
        expect(run.processed_employees).to eq(0)
      end

      it "resets rejected → draft" do
        run.update_column(:status, "rejected")
        run.reprocess!
        expect(run).to be_draft
      end

      it "cannot reprocess an approved run" do
        run.update_column(:status, "approved")
        expect { run.reprocess! }.to raise_error(AASM::InvalidTransition)
      end

      it "cannot reprocess a paid run" do
        run.update_column(:status, "paid")
        expect { run.reprocess! }.to raise_error(AASM::InvalidTransition)
      end
    end
  end

  # ── Helper Methods ────────────────────────────────────────────────────────

  describe "#period_label" do
    it "returns 'March 2026' for month 3, year 2026" do
      run = build(:payroll_run, tenant: tenant, initiated_by: hr_user, month: 3, year: 2026)
      expect(run.period_label).to eq("March 2026")
    end

    it "returns 'January 2025' for month 1, year 2025" do
      run = build(:payroll_run, tenant: tenant, initiated_by: hr_user, month: 1, year: 2025)
      expect(run.period_label).to eq("January 2025")
    end
  end

  describe "#month_name" do
    it "returns the full month name" do
      run = build(:payroll_run, tenant: tenant, initiated_by: hr_user, month: 6, year: 2026)
      expect(run.month_name).to eq("June")
    end
  end

  describe "#progress_percentage" do
    it "returns 0 when total_employees is zero" do
      run = build(:payroll_run, tenant: tenant, initiated_by: hr_user,
                  total_employees: 0, processed_employees: 0)
      expect(run.progress_percentage).to eq(0)
    end

    it "calculates correctly for partial progress" do
      run = build(:payroll_run, tenant: tenant, initiated_by: hr_user,
                  total_employees: 10, processed_employees: 4)
      expect(run.progress_percentage).to eq(40)
    end

    it "returns 100 when all processed" do
      run = build(:payroll_run, tenant: tenant, initiated_by: hr_user,
                  total_employees: 5, processed_employees: 5)
      expect(run.progress_percentage).to eq(100)
    end
  end

  describe "#record_approval" do
    it "stores the approver and timestamp" do
      approver = create(:user, :super_admin)
      run      = create(:payroll_run, tenant: tenant, initiated_by: hr_user)

      freeze_time do
        run.record_approval(approver)
        expect(run.approved_by_id).to eq(approver.id)
        expect(run.approved_at).to be_within(1.second).of(Time.current)
      end
    end
  end

  # ── Scopes ────────────────────────────────────────────────────────────────

  describe ".recent" do
    it "orders by year desc then month desc" do
      r1 = create(:payroll_run, tenant: tenant, initiated_by: hr_user, month: 1, year: 2025)
      r2 = create(:payroll_run, tenant: tenant, initiated_by: hr_user, month: 3, year: 2026)
      r3 = create(:payroll_run, tenant: tenant, initiated_by: hr_user, month: 6, year: 2025)

      expect(PayrollRun.recent.to_a).to eq([ r2, r3, r1 ])
    end
  end
end
