# Display decorator for PayrollRun. Owns view formatting (status badge,
# currency, progress) so models/services stay free of presentation logic.
# Wraps a PayrollRun via SimpleDelegator — any method not defined here is
# forwarded to the underlying record.
class PayrollRunPresenter < SimpleDelegator
  STATUS_BADGE = {
    "draft"        => { label: "Draft",        classes: "badge-neutral" },
    "processing"   => { label: "Processing…",  classes: "badge-processing" },
    "processed"    => { label: "Processed",    classes: "badge-info" },
    "under_review" => { label: "Under Review", classes: "badge-warning" },
    "approved"     => { label: "Approved",     classes: "badge-success" },
    "rejected"     => { label: "Rejected",     classes: "badge-danger" },
    "paid"         => { label: "Paid",         classes: "badge-success" }
  }.freeze

  DEFAULT_BADGE = { classes: "badge-neutral" }.freeze

  # The guided-flow steps shown on the run page. Each AASM status maps onto
  # one step; "rejected" parks the run back on the Approve step.
  STEPS = [
    { key: :review,  label: "Review" },
    { key: :process, label: "Process" },
    { key: :submit,  label: "Submit" },
    { key: :approve, label: "Approve" },
    { key: :pay,     label: "Pay" }
  ].freeze

  STATUS_STEP = {
    "draft"        => 0,
    "processing"   => 1,
    "processed"    => 2,
    "under_review" => 3,
    "rejected"     => 3,
    "approved"     => 4,
    "paid"         => 4
  }.freeze

  # Wrap a collection so each element is presented.
  def self.wrap(collection)
    collection.map { |record| new(record) }
  end

  def current_step_index
    STATUS_STEP.fetch(status, 0)
  end

  # :done, :current or :upcoming — drives the stepper visuals. A paid run
  # shows every step as done.
  def step_state(index)
    return :done if paid? || index < current_step_index

    index == current_step_index ? :current : :upcoming
  end

  def status_badge_label
    badge.fetch(:label) { status.titleize }
  end

  def status_badge_classes
    badge.fetch(:classes)
  end

  def formatted_total_gross
    money(total_gross)
  end

  def formatted_total_deductions
    money(total_deductions)
  end

  def formatted_total_net_pay
    money(total_net_pay)
  end

  def formatted_total_employer_cost
    money(total_employer_cost)
  end

  # Format any rupee amount the way the payroll views expect, with Indian
  # digit grouping: "₹1,23,456".
  def money(value)
    "₹#{ActiveSupport::NumberHelper.number_to_delimited(value.to_f.round(0), delimiter_pattern: /(\d+?)(?=(\d\d)+(\d)(?!\d))/)}"
  end

  # SimpleDelegator forwards == to the wrapped object's identity; keep the
  # decorator transparent for comparisons in specs/views.
  def model
    __getobj__
  end

  private

  def badge
    STATUS_BADGE.fetch(status, DEFAULT_BADGE)
  end
end
