# Run with: bundle exec rails runner -e test script/performance_review.rb
require 'factory_bot'
require 'json'
raise 'Test database required' unless Rails.env.test? && ActiveRecord::Base.connection_db_config.database == 'hrms_test'
Rails.logger.level = Logger::WARN
ActiveJob::Base.queue_adapter = :test

def measure(label)
  queries = []
  instances = Hash.new(0)
  callback = ->(*args) do
    p = args.last
    queries << p[:sql] unless p[:cached] || %w[SCHEMA TRANSACTION].include?(p[:name])
  end
  inst = ->(*args) { p = args.last; instances[p[:class_name]] += p[:record_count] }
  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  result = nil
  ActiveRecord::Base.uncached do
    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
      ActiveSupport::Notifications.subscribed(inst, 'instantiation.active_record') { result = yield }
    end
  end
  elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(1)
  tables = queries.group_by { |q| q[/\b(?:FROM|INTO|UPDATE) "([^"]+)"/, 1] || 'other' }.transform_values(&:size)
  puts({ label: label, queries: queries.size, milliseconds: elapsed, tables: tables, instances: instances }.to_json)
  result
end

ActiveRecord::Base.transaction(requires_new: true) do
  tenant = FactoryBot.create(:tenant, :active, subdomain: "perf-review-#{SecureRandom.hex(5)}")
  ActsAsTenant.with_tenant(tenant) do
    setting = FactoryBot.create(:payroll_setting, tenant: tenant)
    user = FactoryBot.create(:user)
    run = FactoryBot.create(:payroll_run, :approved, tenant: tenant, initiated_by: user, month: 4, year: 2026)
    dept = FactoryBot.create(:department, tenant: tenant)
    desig = FactoryBot.create(:designation, tenant: tenant)
    structure = FactoryBot.create(:salary_structure, tenant: tenant)
    component = FactoryBot.create(:salary_component, tenant: tenant, name: 'Basic')
    FactoryBot.create(:salary_structure_component, salary_structure: structure, salary_component: component, value: 15000)
    employees = []
    slips = []
    [ 5, 25 ].each do |size|
      (size - employees.size).times do
        employee = FactoryBot.create(:employee, tenant: tenant, department: dept, designation: desig)
        employees << employee
        FactoryBot.create(:employee_salary, tenant: tenant, employee: employee, salary_structure: structure, effective_from: Date.new(2026, 4, 1))
        FactoryBot.create(:attendance_summary, tenant: tenant, employee: employee, month: 4, year: 2026, status: :locked)
        slip = FactoryBot.create(:payslip, tenant: tenant, employee: employee, payroll_run: run, month: 4, year: 2026, employer_esi: 487.5)
        slips << slip
        [ [ 'Basic', 'earning', 15000 ], [ 'DA', 'earning', 1000 ], [ 'ESI', 'deduction', 112.5 ], [ 'Professional Tax', 'deduction', 200 ] ].each do |name, type, amount|
          FactoryBot.create(:payslip_line_item, payslip: slip, component_name: name, component_type: type, amount: amount)
        end
      end
      [ Reports::PfMonthlyReportService, Reports::EsiMonthlyReportService, Reports::PtChallanReportService ].each do |klass|
        measure("#{klass.name} employees=#{size}") { klass.new(month: 4, year: 2026).call }
      end
      measure("SalaryCalculator employees=#{size}") do
        Employee.find_in_batches(batch_size: 100) do |employees|
          inputs = Payroll::BatchInputs.new(employees: employees, payroll_run: run)
          employees.each { |employee| Payroll::SalaryCalculator.new(employee: employee, payroll_run: run, payroll_setting: setting, inputs: inputs).call }
        end
      end
      measure("Attendance regenerate locked employees=#{size}") do
        Attendance::SummaryGenerator.new(month: 4, year: 2026, tenant: tenant).call
      end
    end
    measure('YTD employees=25 months=1') { Reports::YtdEarningsReportService.new(financial_year: '2026-27').call }
    (1..11).each do |offset|
      date = Date.new(2026, 4, 1) >> offset
      other_run = FactoryBot.create(:payroll_run, :approved, tenant: tenant, initiated_by: user, month: date.month, year: date.year)
      slips.each do |original|
        slip = FactoryBot.create(:payslip, tenant: tenant, employee: original.employee, payroll_run: other_run, month: date.month, year: date.year)
        original.line_items.each { |li| PayslipLineItem.create!(li.attributes.except('id', 'payslip_id', 'created_at', 'updated_at').merge(payslip_id: slip.id)) }
      end
    end
    measure('YTD employees=25 months=12') { Reports::YtdEarningsReportService.new(financial_year: '2026-27').call }
    measure('PDF generation batch employees=5') do
      payslips = run.payslips.limit(5).to_a
      Payroll::PayslipPdfData.preload(payslips)
      totals = Payroll::PayslipPdfData.ytd(employee_ids: payslips.map(&:employee_id), month: run.month, year: run.year)
      payslips.each { |slip| Payroll::PayslipPdfDocument.call(payslip: slip, ytd: totals[slip.employee_id]) }
    end
    run.update_column(:status, 'processed')
    measure('Payroll reprocess employees=25 line_items=100') { run.reprocess! }
  end
  raise ActiveRecord::Rollback
end
puts 'Completed; all fixture data rolled back.'
