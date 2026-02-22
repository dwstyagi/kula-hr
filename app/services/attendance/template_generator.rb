module Attendance
  # Generates a CSV template for a given month/year, pre-filled with:
  #   - Employee details (code, name, department)
  #   - Auto-calculated values (total_working_days, approved_leaves, lop_leaves)
  #   - Blank columns HR needs to fill: days_present, half_days
  class TemplateGenerator
    HEADERS = %w[
      employee_code
      employee_name
      department
      total_working_days
      days_present
      half_days
      approved_leaves
      lop_leaves
    ].freeze

    def initialize(month:, year:, tenant:)
      @month  = month
      @year   = year
      @tenant = tenant
    end

    def call
      require "csv"

      summaries = AttendanceSummary
        .for_tenant_month(@tenant, @month, @year)
        .includes(employee: :department)
        .order("employees.last_name, employees.first_name")

      CSV.generate(headers: true) do |csv|
        csv << HEADERS

        summaries.each do |s|
          emp = s.employee
          csv << [
            emp.employee_code,
            emp.full_name,
            emp.department&.name || "",
            s.total_working_days.to_f,
            s.days_present.to_f,
            s.half_days.to_f,
            s.approved_leaves.to_f,
            s.lop_leaves.to_f
          ]
        end
      end
    end
  end
end
