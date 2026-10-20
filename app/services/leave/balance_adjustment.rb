module Leave
  class BalanceAdjustment
    Error = Class.new(StandardError)

    def self.call(balance:, days:, reason:, actor:, reference:)
      unless days.to_s.match?(/\A[+-]?\d+(?:\.\d{1,4})?\z/) && days.to_d.nonzero? && days.to_d.abs <= 10000
        raise Error, "Enter a non-zero adjustment of up to 10,000 days with at most four decimal places."
      end
      raise Error, "An adjustment reason is required (up to 1,000 characters)." if reason.blank? || reason.length > 1000
      raise Error, "Reload the balance page before submitting the adjustment." unless reference.to_s.match?(/\A[0-9a-f-]{36}\z/)
      raise Error, "Unpaid leave does not use a balance adjustment." unless balance.leave_type.is_paid?
      raise Error, "Comp-off balances must be backed by approved comp-off credits." if balance.leave_type.code == "CO"
      raise Error, "Only the current financial year can be adjusted." unless balance.financial_year == FinancialYear.label

      balance.with_lock do
        return if balance.leave_balance_entries.exists?(reference: reference)

        if balance.remaining_days + days.to_d < 0 || balance.total_days + days.to_d < balance.used_days + balance.encashed_days
          raise Error, "The adjustment cannot remove days already used or reserved for encashment."
        end
        LeaveAuditContext.set(actor: actor, kind: "hr_adjustment", reason: reason.strip, reference: reference) do
          balance.update!(remaining_days: balance.remaining_days + days.to_d, total_days: balance.total_days + days.to_d)
        end
      end
    end
  end
end
