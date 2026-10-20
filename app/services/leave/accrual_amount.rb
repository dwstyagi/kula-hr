module Leave
  # Difference between cumulative entitlements keeps all twelve credits exact.
  class AccrualAmount
    def self.for(leave_type, period)
      month = (period.month - 4) % 12 + 1
      quota = leave_type.annual_quota.to_d
      (quota * month / 12).round(4) - (quota * (month - 1) / 12).round(4)
    end
  end
end
