class SeedCompOffLeaveType < ActiveRecord::Migration[8.1]
  def up
    now = Time.current
    Tenant.find_each do |tenant|
      next if LeaveType.exists?(tenant_id: tenant.id, code: "CO")

      LeaveType.insert({
        tenant_id:        tenant.id,
        name:             "Comp Off",
        code:             "CO",
        annual_quota:     0,
        carry_forward:    false,
        max_carry_forward: 0,
        is_paid:          true,
        is_active:        true,
        created_at:       now,
        updated_at:       now
      })
    end
  end

  def down
    LeaveType.where(code: "CO").delete_all
  end
end
