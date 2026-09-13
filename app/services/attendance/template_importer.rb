require "csv"
module Attendance
  class TemplateImporter
    MAX_BYTES = 2.megabytes
    MAX_ROWS = 10_000
    REQUIRED_COLUMNS = %w[employee_code days_present half_days].freeze
    Result = Struct.new(:success, :imported_count, :errors, keyword_init: true) do
      def success? = success
    end
    def initialize(file:, month:, year:, tenant:)
      @file, @month, @year, @tenant = file, month, year, tenant
    end
    def call
      return result(false, 0, [ "No file provided" ]) if @file.blank?
      raise ArgumentError, "Attendance file exceeds 2 MB" if @file.respond_to?(:size) && @file.size > MAX_BYTES
      imported = 0
      errors = []
      count = 0
      csv = CSV.new(@file, headers: true, strip: true)
      ActsAsTenant.with_tenant(@tenant) do
        csv.each_slice(100) do |rows|
          missing = REQUIRED_COLUMNS - csv.headers
          return result(false, 0, [ "Missing columns: #{missing.join(', ')}" ]) if missing.any?
          count += rows.size
          raise ArgumentError, "Upload at most #{MAX_ROWS} attendance rows" if count > MAX_ROWS
          codes = rows.map { |row| row["employee_code"]&.strip }
          employees = Employee.where(employee_code: codes).pluck(:employee_code, :id).to_h
          summaries = AttendanceSummary.for_month(@month, @year).where(employee_id: employees.values).index_by(&:employee_id)
          values = {}
          rows.each do |row|
            code = row["employee_code"]&.strip
            summary = summaries[employees[code]]
            error = if !employees[code]
              "Employee '#{code}' not found"
            elsif !summary
              "No summary generated for #{code} — run Generate first"
            elsif summary.locked?
              "#{code} is locked and cannot be updated"
            end
            present = Float(row["days_present"].presence || 0, exception: false)
            half = Float(row["half_days"].presence || 0, exception: false)
            error ||= "Invalid attendance for #{code}" unless present&.finite? && half&.finite? && present >= 0 && half >= 0
            if error
              errors << error if errors.size < 100
              next
            end
            values[summary.id] = [ summary.id, present, half ]
          end
          next if values.empty?
          tuples = values.values.map { |id, present, half| "(#{id.to_i}, #{present.to_f}, #{half.to_f})" }.join(",")
          absent = "GREATEST(s.total_working_days - v.present - v.half * 0.5 - s.approved_leaves - s.lop_leaves, 0)"
          sql = <<~SQL
            UPDATE attendance_summaries s SET days_present = v.present, half_days = v.half,
              unapproved_absences = #{absent}, lop_days = #{absent} + s.lop_leaves,
              paid_days = GREATEST(s.total_working_days - (#{absent}) - s.lop_leaves, 0), updated_at = CURRENT_TIMESTAMP
            FROM (VALUES #{tuples}) AS v(id, present, half)
            WHERE s.id = v.id AND s.tenant_id = #{@tenant.id.to_i} AND s.status = 0 RETURNING s.id
          SQL
          changed = AttendanceSummary.connection.exec_query(sql).rows.size
          imported += changed
          errors << "Some rows were locked during import" if changed < values.size && errors.size < 100
        end
      end
      return result(false, 0, [ "File has no attendance rows" ]) if count.zero?
      result(errors.empty?, imported, errors)
    rescue CSV::MalformedCSVError => error
      result(false, imported || 0, [ "Invalid CSV file: #{error.message}" ])
    end
    private
    def result(success, count, errors)
      Result.new(success: success, imported_count: count, errors: errors)
    end
  end
end
