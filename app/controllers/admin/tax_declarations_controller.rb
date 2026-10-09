module Admin
  # HR review of employee tax declarations. Submitted declarations already
  # count toward TDS; HR verifies the proofs or returns the declaration to
  # draft so the employee can correct it (a draft does not reduce TDS).
  class TaxDeclarationsController < BaseController
    before_action :set_declaration, only: [ :show, :verify, :return_to_draft ]

    def index
      authorize TaxDeclaration
      @financial_year = params[:financial_year].presence || LeaveBalance.current_financial_year
      scope = policy_scope(TaxDeclaration).where(financial_year: @financial_year)
      @status_counts = scope.group(:status).count.transform_keys { |key| TaxDeclaration.statuses.key(key) || key.to_s }
      scope = scope.where(status: params[:status]) if params[:status].present?
      @pagy, @declarations = pagy(:offset, scope.includes(:employee).order(updated_at: :desc), limit: 25)
    end

    def show
      authorize @declaration
    end

    def verify
      authorize @declaration
      @declaration.update!(status: :verified)
      notify_employee("Your tax declaration for FY #{@declaration.financial_year} was verified by HR.", "success")
      redirect_to admin_tax_declaration_path(@declaration), notice: "Declaration verified."
    end

    def return_to_draft
      authorize @declaration
      @declaration.update!(status: :draft)
      note = params[:note].to_s.strip
      notify_employee("HR returned your tax declaration for FY #{@declaration.financial_year} for changes." \
                      "#{" Note: #{note}" if note.present?} It will not reduce TDS until you submit it again.", "error")
      redirect_to admin_tax_declaration_path(@declaration),
        notice: "Declaration returned to #{@declaration.employee.full_name} for changes."
    end

    private

    def set_declaration
      @declaration = policy_scope(TaxDeclaration).includes(:employee, :investment_declarations).find(params[:id])
    end

    def notify_employee(message, kind)
      user = @declaration.employee.user
      return unless user

      ActionCable.server.broadcast("notifications_user_#{user.id}",
        { title: "Tax Declaration", message: message, kind: kind, url: "/portal/tax_declaration" })
    end
  end
end
