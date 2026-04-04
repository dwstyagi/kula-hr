module EmployeePortal
  class TaxDeclarationsController < BaseController
    before_action :ensure_employee!
    before_action :set_declaration

    def show
      authorize @declaration
    end

    def edit
      authorize @declaration
    end

    def update
      authorize @declaration

      if @declaration.update(declaration_params)
        redirect_to employee_portal_tax_declaration_path,
          notice: "Tax declaration saved."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def submit
      authorize @declaration, :submit?

      if @declaration.status_draft?
        @declaration.update!(status: :submitted)
        redirect_to employee_portal_tax_declaration_path,
          notice: "Declaration submitted successfully. Your HR team has been notified."
      else
        redirect_to employee_portal_tax_declaration_path,
          alert: "Only draft declarations can be submitted."
      end
    end

    private

    def set_declaration
      @declaration = TaxDeclaration.find_or_create_by!(
        employee: current_employee,
        financial_year: current_financial_year
      )
    rescue ActiveRecord::RecordNotUnique
      @declaration = TaxDeclaration.find_by!(
        employee: current_employee,
        financial_year: current_financial_year
      )
    end

    def current_financial_year
      today = Date.today
      if today.month >= 4
        "#{today.year}-#{(today.year + 1).to_s.last(2)}"
      else
        "#{today.year - 1}-#{today.year.to_s.last(2)}"
      end
    end

    def ensure_employee!
      unless current_employee
        redirect_to employee_portal_root_path,
          alert: "No employee profile found for your account."
      end
    end

    def declaration_params
      params.require(:tax_declaration).permit(
        :regime, :claiming_hra, :monthly_rent,
        :landlord_name, :landlord_pan, :rental_city,
        :home_loan_interest, :home_loan_principal,
        investment_declarations_attributes: [
          :id, :section, :description, :declared_amount, :_destroy
        ]
      )
    end
  end
end
