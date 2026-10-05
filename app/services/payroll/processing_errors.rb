module Payroll
  # Per-employee failures during a run are recorded and the employee is
  # skipped, so one bad record does not stop payroll for everyone. Failures
  # of the database itself are different: skipping would silently drop
  # employees, so those propagate and the whole job retries.
  module ProcessingErrors
    INFRASTRUCTURE = [
      ActiveRecord::ConnectionNotEstablished,
      ActiveRecord::ConnectionTimeoutError,
      ActiveRecord::QueryCanceled,
      ActiveRecord::LockWaitTimeout,
      ActiveRecord::Deadlocked
    ].freeze

    # Keep what HR sees on the run page bounded.
    MAX_STORED = 200

    module_function

    def entry(employee_id:, name:, error:)
      message = error.is_a?(Exception) ? describe(error) : error.to_s
      { "employee_id" => employee_id, "name" => name, "error" => message.truncate(300) }.with_indifferent_access
    end

    def describe(error)
      return error.message if error.is_a?(Payroll::SalaryCalculator::CalculationError)

      "#{error.class.name}: #{error.message}"
    end
  end
end
