require "rails_helper"

RSpec.describe "Performance query budgets" do
  let(:tenant) { create(:tenant, :active) }
  let(:run) { create(:payroll_run, :approved, tenant: tenant, month: 4, year: 2026) }
  let(:setting) { create(:payroll_setting, tenant: tenant) }
  let(:structure) do
    value = create(:salary_structure, tenant: tenant)
    component = create(:salary_component, tenant: tenant, name: "Basic")
    create(:salary_structure_component, salary_structure: value, salary_component: component, value: 15_000)
    value
  end
  before { set_tenant(tenant); setting; run }

  def sql_count
    count = 0
    callback = ->(*args) { event = args.last; count += 1 unless event[:cached] || event[:name].in?(%w[SCHEMA TRANSACTION]) }
    ActiveRecord::Base.uncached do
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    end
    count
  end

  def add_employee
    employee = create(:employee, tenant: tenant)
    create(:employee_salary, tenant: tenant, employee: employee, salary_structure: structure)
    create(:attendance_summary, :locked, employee: employee, tenant: tenant, month: 4, year: 2026)
    slip = create(:payslip, employee: employee, tenant: tenant, payroll_run: run, month: 4, year: 2026)
    create(:payslip_line_item, payslip: slip, component_name: "Basic", amount: 15_000)
    create(:payslip_line_item, :deduction, payslip: slip, component_name: "ESI", amount: 100)
    create(:payslip_line_item, :deduction, payslip: slip, component_name: "Professional Tax", amount: 200)
    employee
  end

  [ Reports::PfMonthlyReportService, Reports::EsiMonthlyReportService, Reports::PtChallanReportService ].each do |report|
    it "keeps #{report.name} queries constant as headcount grows" do
      add_employee
      small = sql_count { report.new(month: 4, year: 2026).call }
      9.times { add_employee }
      large = sql_count { report.new(month: 4, year: 2026).call }
      expect(large).to be <= small
      expect(large).to be <= 7
    end
  end

  it "calculates a payroll batch without per-employee reads and preserves amounts" do
    10.times { add_employee }
    employees = Employee.order(:id).to_a
    expected = employees.to_h { |employee| [ employee.id, Payroll::SalaryCalculator.new(employee: employee, payroll_run: run, payroll_setting: setting).call.to_h ] }
    employees = Employee.order(:id).to_a
    results = nil
    queries = sql_count do
      inputs = Payroll::BatchInputs.new(employees: employees, payroll_run: run)
      results = employees.to_h do |employee|
        [ employee.id, Payroll::SalaryCalculator.new(employee: employee, payroll_run: run, payroll_setting: setting, inputs: inputs).call.to_h ]
      end
    end
    expect(results).to eq(expected)
    expect(queries).to be <= 12
  end

  it "preserves old-regime deductions and prior-year-boundary TDS with preloaded inputs" do
    employee = add_employee
    run.update_columns(month: 1, year: 2027)
    create(:attendance_summary, :locked, tenant: tenant, employee: employee, month: 1, year: 2027)
    declaration = create(:tax_declaration, :old_regime, tenant: tenant, employee: employee, financial_year: "2026-27")
    %w[80C 80D 80CCD1B 80E].each do |section|
      create(:investment_declaration, tenant: tenant, tax_declaration: declaration, section: section, declared_amount: 10_000)
    end
    prior = create(:payroll_run, :approved, tenant: tenant, month: 12, year: 2026)
    slip = create(:payslip, tenant: tenant, employee: employee, payroll_run: prior, month: 12, year: 2026)
    create(:payslip_line_item, :deduction, payslip: slip, component_name: "TDS", amount: 1000)
    expected = Payroll::SalaryCalculator.new(employee: employee, payroll_run: run, payroll_setting: setting).call
    inputs = Payroll::BatchInputs.new(employees: [ employee ], payroll_run: run)
    actual = Payroll::SalaryCalculator.new(employee: employee, payroll_run: run, payroll_setting: setting, inputs: inputs).call
    expect(inputs.ytd_tds[employee.id]).to eq(1000)
    expect(actual.to_h).to eq(expected.to_h)
  end

  it "skips a locked month without querying leave requests" do
    10.times { add_employee }
    queries = sql_count { Attendance::SummaryGenerator.new(month: 4, year: 2026, tenant: tenant).call }
    expect(queries).to eq(1)
  end

  it "resets a payroll in a bounded number of queries" do
    10.times { add_employee }
    run.update_column(:status, "processed")
    count = sql_count { run.reprocess! }
    expect(count).to be <= 9
    expect(run.payslips).to be_empty
    expect(PayslipLineItem.count).to eq(0)
  end

  it "aggregates YTD without instantiating payslip or line-item records" do
    10.times { add_employee }
    instantiated = []
    callback = ->(*args) { instantiated << args.last[:class_name] }
    result = nil
    ActiveSupport::Notifications.subscribed(callback, "instantiation.active_record") do
      result = Reports::YtdEarningsReportService.new(financial_year: "2026-27").call
    end
    expect(result.rows.size).to eq(10)
    expect(instantiated).not_to include("Payslip", "PayslipLineItem")
    expect(result.to_csv).to eq(Reports::YtdEarningsReportService.new(financial_year: "2026-27").csv_stream.to_a.join)
  end
end
