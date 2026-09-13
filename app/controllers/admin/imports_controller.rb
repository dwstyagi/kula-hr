module Admin
  class ImportsController < BaseController
    PER_PAGE = 10

    def new
      authorize :import, :new?
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

      cache_key = "import_preview_#{current_user.id}_#{ActsAsTenant.current_tenant.id}_#{SecureRandom.hex(12)}"
      Employees::ImportPreview.new(cache_key).write(validation[:validated_rows])
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

      metadata = preview_store.metadata
      unless metadata
        redirect_to new_admin_import_path, alert: "Session expired. Please upload the file again."
        return
      end
      @total_count = metadata.fetch("total")
      @valid_count = metadata.fetch("valid")
      @invalid_count = @total_count - @valid_count
      @total_pages = [ (@total_count.to_f / PER_PAGE).ceil, 1 ].max
      @current_page = params.fetch(:page, 1).to_i.clamp(1, @total_pages)
      @displayed_rows = preview_store.page(@current_page)
      unless @displayed_rows
        redirect_to new_admin_import_path, alert: "Session expired. Please upload the file again."
      end
    end

    def confirm
      authorize :import, :create?

      cache_key = session[:import_cache_key]

      unless cache_key.present?
        redirect_to new_admin_import_path, alert: "Session expired. Please upload the file again."
        return
      end

      if (existing = BackgroundTask.find_by(kind: "employee_import", task_key: cache_key))
        return redirect_to admin_background_task_path(existing)
      end
      rows = preview_store.all_rows
      unless rows.present?
        return redirect_to new_admin_import_path, alert: "Session expired. Please upload the file again."
      end
      tenant = ActsAsTenant.current_tenant
      task = tenant.with_lock do
        BackgroundTask.find_by(kind: "employee_import", task_key: cache_key) ||
          BackgroundTask.enqueue!(tenant: tenant, user: current_user,
            kind: "employee_import", task_key: cache_key, payload: { rows: rows })
      end
      redirect_to admin_background_task_path(task), notice: "Employee import queued."
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

    def preview_store
      Employees::ImportPreview.new(session[:import_cache_key])
    end
  end
end
