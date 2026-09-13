require "rails_helper"

RSpec.describe "Streaming payroll and attendance workflows" do
  let(:tenant) { create(:tenant, :active) }
  let(:run) { create(:payroll_run, :approved, tenant: tenant, month: 5, year: 2026) }
  before do
    set_tenant(tenant)
    create(:payroll_setting, tenant: tenant)
  end

  def add_payslip
    employee = create(:employee, tenant: tenant, pf_applicable: true, bank_account_number: "00001234", ifsc_code: "HDFC0001234")
    slip = create(:payslip, tenant: tenant, payroll_run: run, employee: employee, month: 5, year: 2026)
    create(:payslip_line_item, payslip: slip, component_name: "Basic", amount: 15_000)
    slip
  end

  it "limits report previews while exporting all employees across batch boundaries" do
    105.times { add_payslip }
    service = Reports::PfMonthlyReportService.new(month: 5, year: 2026).call
    expect(service.rows.size).to eq(50)
    expect(service.summary[:employee_count]).to eq(105)
    all = ActsAsTenant.without_tenant { service.stream.to_a.join }
    expect(all.lines.size).to eq(105)
    expect(service.rows).to be_empty
    last = Reports::PfMonthlyReportService.new(month: 5, year: 2026).call(offset: 100)
    expect(last.rows.size).to eq(5)
    expect(last.summary[:employee_count]).to eq(105)
    bank = Payroll::BankFileGenerators::GenericCsv.new(payroll_run: run)
    expect(CSV.parse(bank.stream.to_a.join, headers: true).size).to eq(105)
  end

  it "updates attendance in a batch and preserves the model's computed totals" do
    rows = 10.times.map do
      employee = create(:employee, tenant: tenant)
      create(:attendance_summary, tenant: tenant, employee: employee, month: 5, year: 2026,
        total_working_days: 22, approved_leaves: 2, lop_leaves: 1)
      "#{employee.employee_code},15,2"
    end
    sql = []
    callback = ->(*args) { sql << args.last[:sql] unless args.last[:name].in?(%w[SCHEMA TRANSACTION]) }
    ActiveRecord::Base.uncached do
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        result = Attendance::TemplateImporter.new(file: StringIO.new("employee_code,days_present,half_days\n#{rows.join("\n")}\n"),
          tenant: tenant, month: 5, year: 2026).call
        expect(result.imported_count).to eq(10)
      end
    end
    expect(sql.size).to eq(3)
    summary = AttendanceSummary.first
    expect(summary.unapproved_absences).to eq(3)
    expect(summary.lop_days).to eq(4)
    expect(summary.paid_days).to eq(18)
  end

  it "does not overwrite attendance locked after the importer read it" do
    employee = create(:employee, tenant: tenant)
    summary = create(:attendance_summary, tenant: tenant, employee: employee, month: 5, year: 2026, days_present: 10)
    connection = AttendanceSummary.connection
    allow(connection).to receive(:exec_query).and_wrap_original do |method, sql, *args|
      summary.update_column(:status, :locked) if sql.start_with?("UPDATE attendance_summaries")
      method.call(sql, *args)
    end
    result = Attendance::TemplateImporter.new(file: StringIO.new("employee_code,days_present,half_days\n#{employee.employee_code},20,0\n"),
      tenant: tenant, month: 5, year: 2026).call
    expect(result.imported_count).to eq(0)
    expect(summary.reload.days_present).to eq(10)
    expect(result.errors).to include("Some rows were locked during import")
  end

  it "rejects oversized attendance before reading it" do
    file = StringIO.new("x" * (Attendance::TemplateImporter::MAX_BYTES + 1))
    expect(file).not_to receive(:gets)
    expect { Attendance::TemplateImporter.new(file: file, tenant: tenant, month: 5, year: 2026).call }
      .to raise_error(ArgumentError, /exceeds 2 MB/)
  end

  it "publishes a ZIP only for the current payslip version and acknowledges delivery" do
    slip = add_payslip
    Dir.mktmpdir do |directory|
      allow(Payroll::PayslipArchive).to receive(:root).and_return(Pathname(directory))
      allow(Payroll::PayslipPdfDocument).to receive(:call).and_return("%PDF fake")
      version = Payroll::PayslipArchive.version(run)
      dispatch = JobDispatch.enqueue!(BulkPayslipPdfJob, run.id, version)
      BulkPayslipPdfJob.perform_now(run.id, version, dispatch_id: dispatch.id)
      path = Payroll::PayslipArchive.path(run, version)
      expect(Payroll::PayslipArchive.ready?(path)).to be(true)
      Zip::File.open(path) do |zip|
        expect(zip.entries.size).to eq(1)
        expect(zip.entries.first.get_input_stream.read).to eq("%PDF fake")
      end
      expect(JobDispatch.exists?(dispatch.id)).to be(false)
      slip.update!(revision_notes: "corrected")
      expect(Payroll::PayslipArchive.version(run.reload)).not_to eq(version)
      expect(Dir.children(directory).grep(/part/)).to be_empty
    end
  end

  it "discards archive output when a payslip changes during generation" do
    slip = add_payslip
    Dir.mktmpdir do |directory|
      allow(Payroll::PayslipArchive).to receive(:root).and_return(Pathname(directory))
      version = Payroll::PayslipArchive.version(run)
      allow(Payroll::PayslipPdfDocument).to receive(:call) do
        slip.update!(revision_notes: "corrected during generation")
        "%PDF fake"
      end
      BulkPayslipPdfJob.perform_now(run.id, version)
      expect(Dir.children(directory)).to be_empty
    end
  end
end
