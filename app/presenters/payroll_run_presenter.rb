# Display decorator for PayrollRun. Owns view formatting (status badge,
# currency, progress) so models/services stay free of presentation logic.
# Wraps a PayrollRun via SimpleDelegator — any method not defined here is
# forwarded to the underlying record.
class PayrollRunPresenter < SimpleDelegator
  STATUS_BADGE = {
    "draft"        => { label: "Draft",       classes: "bg-gray-100 text-gray-600" },
    "processing"   => { label: "Processing…", classes: "bg-yellow-100 text-yellow-700" },
    "processed"    => { label: "Processed",    classes: "bg-blue-100 text-blue-700" },
    "under_review" => { label: "Under Review", classes: "bg-purple-100 text-purple-700" },
    "approved"     => { label: "Approved",     classes: "bg-green-100 text-green-700" },
    "rejected"     => { label: "Rejected",     classes: "bg-red-100 text-red-700" },
    "paid"         => { label: "Paid",         classes: "bg-emerald-100 text-emerald-700" }
  }.freeze

  DEFAULT_BADGE = { classes: "bg-gray-100 text-gray-600" }.freeze

  # Wrap a collection so each element is presented.
  def self.wrap(collection)
    collection.map { |record| new(record) }
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

  # Format any rupee amount the way the payroll views expect: "₹1,23,456".
  def money(value)
    "₹#{ActiveSupport::NumberHelper.number_to_delimited(value.to_f.round(0))}"
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
