module Employees
  class CodeAllocator
    def self.reserve(tenant, count = 1)
      return [] if count.zero?
      tenant.with_lock do
        previous = tenant.employee_sequence
        if previous.zero?
          previous = Employee.where(tenant_id: tenant.id).where("employee_code ~ '^EMP[0-9]+$'")
            .maximum(Arel.sql("CAST(SUBSTRING(employee_code FROM 4) AS bigint)")).to_i
        end
        tenant.update_column(:employee_sequence, previous + count)
        (previous + 1..previous + count).map { |number| "EMP#{number.to_s.rjust(4, '0')}" }
      end
    end
  end
end
