# Indian financial year: 1 April – 31 March, labelled like "2026-27".
# The single place that turns dates and payroll periods into FY labels.
module FinancialYear
  module_function

  # Calendar year in which the FY containing `date` starts.
  def start_year(date) = date.month >= 4 ? date.year : date.year - 1

  def label_for_start_year(year) = "#{year}-#{(year + 1).to_s.last(2)}"

  def label(date = Date.current) = label_for_start_year(start_year(date))

  # FY of a payroll period (month 1–12, year).
  def for_period(month, year) = label(Date.new(year.to_i, month.to_i, 1))

  # April = 1 … March = 12
  def position(month) = month >= 4 ? month - 3 : month + 9
end
