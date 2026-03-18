module Admin
  class ImportsController < BaseController
    PER_PAGE = 10

    def new
      authorize :import, :new?
      tenant = ActsAsTenant.current_tenant
      if tenant.at_employee_limit?
        return redirect_to admin_employees_path,
                           alert: "Trial accounts are limited to #{Tenant::TRIAL_EMPLOYEE_LIMIT} employees. Upgrade to add more."
      end
    end

    def create
      authorize :import, :create?

      unless params[:file].present?
        flash.now[:alert] = "Please select a file to upload."
        return render :new, status: :unprocessable_content
      end

      parse_result = Employees::FileParser.new(params[:file]).call

      unless parse_result.success?
        flash.now[:alert] = parse_result.errors.first
        return render :new, status: :unprocessable_content
      end

      validation = Employees::BulkValidator.new(
        parse_result.rows,
        tenant: ActsAsTenant.current_tenant
      ).call

      # Cache validated rows so preview + confirm can use them without re-parsing
      cache_key = "import_preview_#{current_user.id}_#{ActsAsTenant.current_tenant.id}"
      Rails.cache.write(cache_key, validation[:validated_rows], expires_in: 30.minutes)
      session[:import_cache_key] = cache_key

      redirect_to preview_admin_imports_path
    end

    def preview
      authorize :import, :new?

      cache_key = session[:import_cache_key]

      unless cache_key.present?
        redirect_to new_admin_import_path, alert: "Session expired. Please upload the file again."
        return
      end

      all_rows = Rails.cache.read(cache_key)

      unless all_rows.present?
        redirect_to new_admin_import_path, alert: "Session expired. Please upload the file again."
        return
      end

      @valid_rows   = all_rows.select { |r| r["_valid"] }
      @invalid_rows = all_rows.reject { |r| r["_valid"] }
      @total_count  = all_rows.size

      tenant = ActsAsTenant.current_tenant
      if tenant.trial?
        @trial_remaining = Tenant::TRIAL_EMPLOYEE_LIMIT - tenant.employees.count
        @trial_will_skip = [ @valid_rows.size - @trial_remaining, 0 ].max
      end

      # Manual pagination
      @current_page = [ (params[:page] || 1).to_i, 1 ].max
      @total_pages  = [ (@total_count.to_f / PER_PAGE).ceil, 1 ].max
      @current_page = @total_pages if @current_page > @total_pages

      @displayed_rows = all_rows.slice((@current_page - 1) * PER_PAGE, PER_PAGE) || []
    end

    def confirm
      authorize :import, :create?

      cache_key = session[:import_cache_key]

      unless cache_key.present?
        redirect_to new_admin_import_path, alert: "Session expired. Please upload the file again."
        return
      end

      validated_rows = Rails.cache.read(cache_key)

      unless validated_rows.present?
        redirect_to new_admin_import_path, alert: "Session expired. Please upload the file again."
        return
      end

      valid_rows   = validated_rows.select { |r| r["_valid"] }
      invalid_rows = validated_rows.reject { |r| r["_valid"] }

      tenant = ActsAsTenant.current_tenant
      if tenant.trial?
        remaining = Tenant::TRIAL_EMPLOYEE_LIMIT - tenant.employees.count
        if remaining <= 0
          Rails.cache.delete(cache_key)
          session.delete(:import_cache_key)
          return redirect_to admin_employees_path,
                             alert: "Trial accounts are limited to #{Tenant::TRIAL_EMPLOYEE_LIMIT} employees. Upgrade to add more."
        end
        if valid_rows.size > remaining
          skipped_count = valid_rows.size - remaining
          valid_rows    = valid_rows.first(remaining)
          flash[:alert] = "Trial limit reached: #{skipped_count} #{'row'.pluralize(skipped_count)} skipped. Upgrade to import all employees."
        end
      end

      import_employees(valid_rows)

      Rails.cache.delete(cache_key)
      session.delete(:import_cache_key)

      if invalid_rows.any?
        # Store generated xlsx in cache so download_errors action can serve it
        error_key = "import_errors_#{current_user.id}_#{ActsAsTenant.current_tenant.id}"
        xlsx = Employees::ErrorReportGenerator.new(invalid_rows).call
        Rails.cache.write(error_key, xlsx, expires_in: 10.minutes)
        session[:import_error_key]   = error_key
        session[:import_error_count] = invalid_rows.size

        redirect_to admin_employees_path,
                    notice: "#{valid_rows.size} #{'employee'.pluralize(valid_rows.size)} imported. #{invalid_rows.size} rows had errors."
      else
        redirect_to admin_employees_path,
                    notice: "#{valid_rows.size} #{'employee'.pluralize(valid_rows.size)} imported successfully."
      end
    end

    def download_errors
      authorize :import, :new?

      error_key = session[:import_error_key]

      unless error_key.present?
        redirect_to admin_employees_path, alert: "No error report available."
        return
      end

      xlsx = Rails.cache.read(error_key)

      unless xlsx.present?
        session.delete(:import_error_key)
        session.delete(:import_error_count)
        redirect_to admin_employees_path, alert: "Error report has expired. Please re-import your file."
        return
      end

      Rails.cache.delete(error_key)
      session.delete(:import_error_key)
      session.delete(:import_error_count)

      send_data xlsx,
                filename: "import_errors_#{Date.today.strftime('%d_%m_%Y')}.xlsx",
                type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                disposition: "attachment"
    end

    private

    def import_employees(rows)
      return if rows.empty?

      tenant = ActsAsTenant.current_tenant
      now    = Time.current

      # Determine starting employee code once (one query)
      last_code   = Employee.where(tenant_id: tenant.id).order(employee_code: :desc).pick(:employee_code)
      next_number = last_code&.match?(/\AEMP\d+\z/) ? last_code.delete_prefix("EMP").to_i + 1 : 1

      # Bulk resolve departments/designations — a few queries total, not N
      dept_map  = resolve_departments(rows, tenant)
      desig_map = resolve_designations(rows, tenant)

      records = []

      rows.each_with_index do |row, i|
        employee = Employee.new(
          tenant_id:           tenant.id,
          # Pre-assign code so the before_validation callback skips generation
          employee_code:       "EMP#{(next_number + i).to_s.rjust(4, '0')}",
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
        if employee.valid?
          records << employee.attributes
                             .except("id")
                             .merge("created_at" => now, "updated_at" => now)
        else
          Rails.logger.warn("[Import] Row #{row['_row']} failed model validation: #{employee.errors.full_messages.join(', ')}")
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
