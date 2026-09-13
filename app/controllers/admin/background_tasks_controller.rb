module Admin
  class BackgroundTasksController < BaseController
    def show
      @task = policy_scope(BackgroundTask).find(params[:id])
      authorize @task
    end

    def retry_task
      task = policy_scope(BackgroundTask).find(params[:id])
      authorize task, :retry_task?
      task.with_lock do
        if task.status == "failed"
          task.update!(status: "queued")
          JobDispatch.enqueue!(BackgroundTaskJob, task.id)
        end
      end
      redirect_to admin_background_task_path(task)
    rescue ActiveRecord::RecordNotUnique
      redirect_to admin_background_task_path(task), alert: "Another operation is already in progress."
    end

    def download_errors
      task = policy_scope(BackgroundTask).find(params[:id])
      authorize task, :show?
      rows = task.result.fetch("invalid_rows", [])
      send_data Employees::ErrorReportGenerator.new(rows).call,
        filename: "import_errors.xlsx", type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    end
  end
end
