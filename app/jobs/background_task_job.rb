class BackgroundTaskJob < ApplicationJob
  self.enqueue_after_transaction_commit = true
  queue_as :default

  def perform(task_id, dispatch_id: nil)
    task = ActsAsTenant.without_tenant { BackgroundTask.find_by(id: task_id) }
    unless task
      JobDispatch.where(id: dispatch_id).delete_all
      return
    end
    ActsAsTenant.with_tenant(task.tenant) do
      # Work and completion commit together: a worker crash rolls back changes,
      # and a duplicate delivery observes completion and does nothing.
      task.with_lock do
        unless task.pending?
          JobDispatch.where(id: dispatch_id).delete_all
          return
        end
        task.update!(status: "running")
        result = case task.kind
        when "attendance"
          Attendance::SummaryGenerator.new(month: task.payload.fetch("month"),
            year: task.payload.fetch("year"), tenant: task.tenant).call
          {}
        when "attendance_import"
          imported = Attendance::TemplateImporter.new(file: StringIO.new(task.payload.fetch("csv")),
            month: task.payload.fetch("month"), year: task.payload.fetch("year"), tenant: task.tenant).call
          { imported_count: imported.imported_count, errors: imported.errors }
        when "payroll_reset"
          run = PayrollRun.find(task.payload.fetch("payroll_run_id"))
          run.with_lock { run.reprocess! if run.resetting? }
          {}
        when "employee_import"
          Employees::Importer.new(rows: task.payload.fetch("rows"), tenant: task.tenant).call
        end
        # Imported personal data is needed only until the transaction succeeds.
        task.update!(status: "completed", result: result, payload: task.payload.except("rows", "csv"))
        JobDispatch.where(id: dispatch_id).delete_all
      end
    end
  rescue StandardError => error
    Rails.logger.error("[BackgroundTask #{task_id}] #{error.class}: #{error.message}")
    ActsAsTenant.with_tenant(task.tenant) do
      task.with_lock do
        task.update!(status: "failed")
        JobDispatch.where(id: dispatch_id).delete_all
      end
    end if task
    # The status page provides an explicit retry, using the retained inputs.
  end
end
