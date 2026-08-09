module Leave
  # Computes encashment payout: days × (basic_monthly ÷ 30)
  # Basic monthly is derived from the employee's current salary structure.
  class EncashmentCalculator
    class NoSalaryError < StandardError; end

    def initialize(employee:, number_of_days:, as_of: Date.current)
      @employee       = employee
      @number_of_days = number_of_days.to_d
      @as_of          = as_of
    end

    def call
      basic_monthly = fetch_basic_monthly
      ((@number_of_days * basic_monthly) / 30).round(2)
    end

    private

    def fetch_basic_monthly
      salary = @employee.employee_salaries
        .where("effective_from <= ?", @as_of)
        .where("effective_to IS NULL OR effective_to >= ?", @as_of)
        .order(effective_from: :desc)
        .first
      raise NoSalaryError, "No salary assigned for #{@employee.full_name}" unless salary

      structure   = salary.salary_structure
      basic_component = structure.salary_structure_components
                                 .joins(:salary_component)
                                 .find_by(salary_components: { name: "Basic" })

      unless basic_component
        raise NoSalaryError, "No Basic component found in salary structure for #{@employee.full_name}"
      end

      annual_ctc    = salary.annual_ctc.to_d
      basic_percent = basic_component.value.to_d
      ((annual_ctc * basic_percent / 100) / 12).round(2)
    end
  end
end
