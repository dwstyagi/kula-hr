class LeaveAuditContext < ActiveSupport::CurrentAttributes
  attribute :actor, :reason, :kind, :reference
end
