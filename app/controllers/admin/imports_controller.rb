module Admin
  class ImportsController < BaseController
    def new
      authorize :import, :new?
    end

    def create
      authorize :import, :create?

      unless params[:file].present?
        flash.now[:alert] = "Please select a file to upload."
        return render :new, status: :unprocessable_content
      end

      result = Employees::FileParser.new(params[:file]).call

      unless result.success?
        flash.now[:alert] = result.errors.first
        return render :new, status: :unprocessable_content
      end

      @rows  = result.rows
      @valid_count   = @rows.size
      @preview_rows  = @rows.first(5)

      render :preview
    end
  end
end
