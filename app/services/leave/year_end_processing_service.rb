module Leave
  # Runs at financial year close (April 1st, 1am) to roll over leave balances.
  # For each active/probation employee:
  #   - carry_forward leave types: carries min(max_carry_forward, remaining_days) into new FY
  #   - non-carry-forward types: new FY starts fresh
  # New FY balance is seeded with April's monthly accrual already included so the
  # April 1st midnight monthly accrual job (which ran on old FY records) is not missed.
  class YearEndProcessingService
    WORKING_STATUSES = %w[active probation].freeze

    def self.run_for_all_tenants
      Tenant.where(status: %w[trial active]).find_each do |tenant|
        ActsAsTenant.with_tenant(tenant) do
          new(tenant: tenant).call
        end
      rescue StandardError => e
        Rails.logger.error("[YearEndProcessing] Failed for tenant #{tenant.id} (#{tenant.subdomain}): #{e.message}")
      end
    end

    def initialize(tenant:)
      @tenant = tenant
    end

    def call
      leave_types = LeaveType.active.paid.to_a
      return if leave_types.empty?

      working_ids = Employee.where(employment_status: WORKING_STATUSES).ids
      return if working_ids.empty?

      current_fy = LeaveBalance.current_financial_year
      new_fy     = next_financial_year
      now        = Time.current

      current_balances = LeaveBalance
        .where(financial_year: current_fy, employee_id: working_ids)
        .index_by { |b| [ b.employee_id, b.leave_type_id ] }

      # Employees who chose encashment — their carry-forward days become 0
      approved_encashments = LeaveEncashmentRequest
        .where(financial_year: current_fy, status: :approved, employee_id: working_ids)
        .pluck(:employee_id, :leave_type_id)
        .to_set

      records = working_ids.flat_map do |employee_id|
        leave_types.map do |leave_type|
          current = current_balances[ [ employee_id, leave_type.id ] ]
          encashed = approved_encashments.include?([ employee_id, leave_type.id ])
          carried = encashed ? 0.0 : carried_days(leave_type, current)
          first_month = (leave_type.annual_quota / 12.0).round(2)
          total = first_month + carried

          {
            tenant_id:            @tenant.id,
            employee_id:          employee_id,
            leave_type_id:        leave_type.id,
            financial_year:       new_fy,
            total_days:           total,
            remaining_days:       total,
            used_days:            0,
            carried_forward_days: carried,
            created_at:           now,
            updated_at:           now
          }
        end
      end

      LeaveBalance.insert_all(records, unique_by: %i[employee_id leave_type_id financial_year]) if records.any?
    end

    private

    def carried_days(leave_type, current_balance)
      return 0.0 unless leave_type.carry_forward? && current_balance
      [ leave_type.max_carry_forward, current_balance.remaining_days ].min.to_f
    end

    def next_financial_year
      today = Date.today
      # If called in April (new FY just started), next FY is current year+1
      year = today.month >= 4 ? today.year : today.year - 1
      "#{year + 1}-#{(year + 2).to_s.last(2)}"
    end
  end
end
