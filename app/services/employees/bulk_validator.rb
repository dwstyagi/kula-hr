module Employees
  class BulkValidator
    def initialize(rows, tenant:)
      @rows   = rows
      @tenant = tenant
    end

    def call
      existing_emails = Employee.where(tenant: @tenant)
                                .pluck(:email)
                                .map(&:downcase)
                                .to_set

      seen_emails = {}

      validated_rows = @rows.map do |row|
        result = RowValidator.new(row).call
        errors = result[:errors].dup
        email  = row["email"]&.strip&.downcase

        if email.present?
          # Duplicate within the file
          if seen_emails.key?(email)
            errors << "Duplicate email in file (first seen on row #{seen_emails[email]})"
          else
            seen_emails[email] = row["_row"]
          end

          # Already exists in the database
          errors << "Email already exists in the system" if existing_emails.include?(email)
        end

        row.merge("_errors" => errors, "_valid" => errors.empty?)
      end

      valid_rows   = validated_rows.select { |r| r["_valid"] }
      invalid_rows = validated_rows.reject { |r| r["_valid"] }

      {
        validated_rows: validated_rows,
        valid_rows:     valid_rows,
        invalid_rows:   invalid_rows
      }
    end
  end
end
