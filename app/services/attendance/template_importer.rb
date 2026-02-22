module Attendance
  # Imports HR-filled attendance CSV and updates AttendanceSummary records.
  # Only updates days_present and half_days; recalculation happens in the model.
  # Skips locked records and missing employees silently (reports as warnings).
  class TemplateImporter
    Result = Struct.new(:success, :imported_count, :errors, keyword_init: true) do
      def success? = success
    end

    REQUIRED_COLUMNS = %w[employee_code days_present half_days].freeze

    def initialize(file:, month:, year:, tenant:)
      @file   = file
      @month  = month
      @year   = year
      @tenant = tenant
    end

    def call
      require "csv"

      return error_result("No file provided") if @file.blank?

      csv = CSV.parse(@file.read, headers: true, strip: true)

      missing = REQUIRED_COLUMNS - csv.headers.map(&:downcase)
      return error_result("Missing columns: #{missing.join(', ')}") if missing.any?

      errors         = []
      imported_count = 0

      ActsAsTenant.with_tenant(@tenant) do
        csv.each_with_index do |row, idx|
          row_num = idx + 2  # 1-based, +1 for header

          emp_code     = row["employee_code"]&.strip
          days_present = row["days_present"].to_f
          half_days    = row["half_days"].to_f

          employee = Employee.find_by(employee_code: emp_code)
          unless employee
            errors << "Row #{row_num}: employee '#{emp_code}' not found"
            next
          end

          summary = AttendanceSummary.find_by(
            employee: employee, month: @month, year: @year
          )
          unless summary
            errors << "Row #{row_num}: no summary generated for #{emp_code} — run Generate first"
            next
          end

          if summary.locked?
            errors << "Row #{row_num}: #{emp_code} is locked and cannot be updated"
            next
          end

          if summary.update(days_present: days_present, half_days: half_days)
            imported_count += 1
          else
            errors << "Row #{row_num}: #{emp_code} — #{summary.errors.full_messages.join(', ')}"
          end
        end
      end

      Result.new(success: errors.empty?, imported_count: imported_count, errors: errors)
    rescue CSV::MalformedCSVError => e
      error_result("Invalid CSV file: #{e.message}")
    end

    private

    def error_result(msg)
      Result.new(success: false, imported_count: 0, errors: [msg])
    end
  end
end
