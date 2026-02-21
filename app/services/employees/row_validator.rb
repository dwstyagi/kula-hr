module Employees
  class RowValidator
    REQUIRED_FIELDS = %w[first_name last_name email joining_date employment_status].freeze
    DATE_FIELDS     = %w[joining_date date_of_birth confirmation_date].freeze
    DATE_FORMAT     = "%d/%m/%Y"

    def initialize(row)
      @row    = row
      @errors = []
    end

    def call
      validate_required_fields
      validate_email
      validate_dates
      validate_employment_status
      validate_gender
      validate_pan
      validate_aadhaar
      validate_pincode

      { valid: @errors.empty?, errors: @errors }
    end

    private

    def validate_required_fields
      REQUIRED_FIELDS.each do |field|
        @errors << "#{field.humanize} is required" if @row[field].blank?
      end
    end

    def validate_email
      return if @row["email"].blank?

      @errors << "Email is not valid" unless @row["email"].match?(URI::MailTo::EMAIL_REGEXP)
    end

    def validate_dates
      DATE_FIELDS.each do |field|
        next if @row[field].blank?

        Date.strptime(@row[field], DATE_FORMAT)
      rescue Date::Error
        @errors << "#{field.humanize} must be in DD/MM/YYYY format (e.g. 15/08/1990)"
      end
    end

    def validate_employment_status
      return if @row["employment_status"].blank?

      unless Employee::EMPLOYMENT_STATUSES.include?(@row["employment_status"])
        @errors << "Employment status must be one of: #{Employee::EMPLOYMENT_STATUSES.join(', ')}"
      end
    end

    def validate_gender
      return if @row["gender"].blank?

      @errors << "Gender must be one of: #{Employee::GENDERS.join(', ')}" unless Employee::GENDERS.include?(@row["gender"])
    end

    def validate_pan
      return if @row["pan_number"].blank?

      @errors << "PAN must be in format ABCDE1234F" unless @row["pan_number"].match?(/\A[A-Z]{5}\d{4}[A-Z]\z/)
    end

    def validate_aadhaar
      return if @row["aadhaar_number"].blank?

      @errors << "Aadhaar must be 12 digits" unless @row["aadhaar_number"].match?(/\A\d{12}\z/)
    end

    def validate_pincode
      return if @row["pincode"].blank?

      @errors << "Pincode must be 6 digits" unless @row["pincode"].match?(/\A\d{6}\z/)
    end
  end
end
