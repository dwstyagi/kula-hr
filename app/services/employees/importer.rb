module Employees
  class Importer
    def initialize(rows:, tenant:)
      @rows, @tenant = rows, tenant
    end

    def call
      ActsAsTenant.with_tenant(@tenant) do
        @tenant.with_lock do
          # Tenant locking is shared with ordinary employee code allocation.
          validation = BulkValidator.new(@rows, tenant: @tenant).call
          @invalid_rows = validation[:invalid_rows]
          rows = validation[:valid_rows]
          if @tenant.trial? && Employee.count + rows.size > Tenant::TRIAL_EMPLOYEE_LIMIT
            raise ArgumentError, "The import exceeds the trial employee limit"
          end
          count = insert_rows(rows)
          { imported_count: count, invalid_rows: @invalid_rows }
        end
      end
    end

    private

    def insert_rows(rows)
      return 0 if rows.empty?

      tenant = @tenant
      now    = Time.current

      codes = Employees::CodeAllocator.reserve(tenant, rows.size)

      # Bulk resolve departments/designations — a few queries total, not N
      dept_map  = resolve_departments(rows, tenant)
      desig_map = resolve_designations(rows, tenant)

      records = []

      rows.each_with_index do |row, i|
        employee = Employee.new(
          tenant:              tenant,
          # Pre-assign code so the before_validation callback skips generation
          employee_code:       codes.fetch(i),
          first_name:          row["first_name"]&.strip,
          last_name:           row["last_name"]&.strip,
          email:               row["email"]&.strip&.downcase,
          phone:               row["phone"]&.strip.presence,
          joining_date:        parse_date(row["joining_date"]),
          employment_status:   row["employment_status"]&.strip,
          gender:              row["gender"]&.strip.presence,
          date_of_birth:       parse_date(row["date_of_birth"]),
          confirmation_date:   parse_date(row["confirmation_date"]),
          department_id:       dept_map[row["department"]&.strip],
          designation_id:      desig_map[row["designation"]&.strip],
          pan_number:          row["pan_number"]&.strip.presence,
          aadhaar_number:      row["aadhaar_number"]&.strip.presence,
          uan_number:          row["uan_number"]&.strip.presence,
          esi_number:          row["esi_number"]&.strip.presence,
          current_address:     row["current_address"]&.strip.presence,
          city:                row["city"]&.strip.presence,
          state:               row["state"]&.strip.presence,
          pincode:             row["pincode"]&.strip.presence,
          bank_name:           row["bank_name"]&.strip.presence,
          bank_account_number: row["bank_account_number"]&.strip.presence,
          ifsc_code:           row["ifsc_code"]&.strip.presence,
          emergency_contact_name:     row["emergency_contact_name"]&.strip.presence,
          emergency_contact_phone:    row["emergency_contact_phone"]&.strip.presence,
          emergency_contact_relation: row["emergency_contact_relation"]&.strip.presence
        )

        # Runs before_validation callbacks + all model validations
        if employee.valid?(:bulk_import)
          records << employee.attributes
                             .except("id")
                             .merge("created_at" => now, "updated_at" => now)
        else
          @invalid_rows << row.merge("_errors" => employee.errors.full_messages, "_valid" => false)
        end
      end

      if records.any?
        # Capture emails before insert to identify newly created employees
        emails = records.map { |r| r["email"] }

        records.each_slice(500) { |batch| Employee.insert_all!(batch) }

        # Allocate leave balances in bulk — insert_all bypasses callbacks so we do it manually
        employees = Employee.where(email: emails).to_a
        Leave::LeaveBalanceAllocator.new(employees: employees).call
      end
      records.size
    end

    # Returns { "Engineering" => dept_id, ... } — upserts missing names in one pass
    def resolve_departments(rows, tenant)
      names = rows.map { |r| r["department"]&.strip }.compact_blank.uniq
      return {} if names.empty?

      ActsAsTenant.with_tenant(tenant) do
        existing = Department.where(name: names).pluck(:name, :id).to_h
        missing  = names - existing.keys
        if missing.any?
          now = Time.current
          Department.insert_all(missing.map { |n| { tenant_id: tenant.id, name: n, created_at: now, updated_at: now } })
          existing.merge!(Department.where(name: missing).pluck(:name, :id).to_h)
        end
        existing
      end
    end

    # Returns { "Software Engineer" => desig_id, ... }
    def resolve_designations(rows, tenant)
      names = rows.map { |r| r["designation"]&.strip }.compact_blank.uniq
      return {} if names.empty?

      ActsAsTenant.with_tenant(tenant) do
        existing = Designation.where(name: names).pluck(:name, :id).to_h
        missing  = names - existing.keys
        if missing.any?
          now = Time.current
          Designation.insert_all(missing.map { |n| { tenant_id: tenant.id, name: n, created_at: now, updated_at: now } })
          existing.merge!(Designation.where(name: missing).pluck(:name, :id).to_h)
        end
        existing
      end
    end

    def parse_date(value)
      return nil if value.blank?
      Date.strptime(value.to_s.strip, "%d/%m/%Y")
    rescue Date::Error
      nil
    end
  end
end
