class LeaveBalance < ApplicationRecord
  acts_as_tenant :tenant
  belongs_to :tenant
  belongs_to :employee
  belongs_to :leave_type
  has_many :leave_balance_debits, dependent: :destroy
  has_many :leave_balance_entries, dependent: :delete_all
  after_save :record_balance_entry

  AUDITED_FIELDS = %w[total_days used_days remaining_days carried_forward_days encashed_days].freeze

  validates :financial_year, presence: true
  validates :total_days, :used_days, :remaining_days, :carried_forward_days,
            numericality: { greater_than_or_equal_to: 0 }
  validates :employee_id, uniqueness: { scope: [ :leave_type_id, :financial_year ],
                                        message: "already has a balance for this leave type and year" }

  scope :for_year, ->(fy) { where(financial_year: fy) }
  scope :current, -> { for_year(LeaveBalance.current_financial_year) }

  def self.current_financial_year
    FinancialYear.label
  end

  private

  def record_balance_entry
    return unless AUDITED_FIELDS.any? { |field| saved_change_to_attribute?(field) }

    values = AUDITED_FIELDS.index_with { |field| public_send(field) }
    changes = AUDITED_FIELDS.to_h do |field|
      before, after = saved_change_to_attribute(field) || [ public_send(field), public_send(field) ]
      [ "change_#{field}", after.to_d - before.to_d ]
    end
    kind = if previously_new_record?
      "opening"
    elsif LeaveAuditContext.kind.present?
      LeaveAuditContext.kind
    elsif changes["change_encashed_days"].positive?
      "encashment"
    elsif changes["change_used_days"].positive?
      "leave_approved"
    elsif changes["change_used_days"].negative?
      "leave_cancelled"
    else
      "credit_or_expiry"
    end
    leave_balance_entries.create!(tenant: tenant, actor: LeaveAuditContext.actor,
      kind: kind, reason: LeaveAuditContext.reason, reference: LeaveAuditContext.reference, **values, **changes)
  end
end
