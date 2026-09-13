module Leave
  # Runs at financial year close (April 1st, 1am) to roll over leave balances.
  # For each active/probation employee:
  #   - carry_forward leave types: carries min(max_carry_forward, remaining_days) into new FY
  #   - non-carry-forward types: new FY starts fresh
  # New FY balance is seeded with April's monthly accrual already included so the
  # monthly accrual explicitly skips April to avoid crediting it twice.
  class YearEndProcessingService
    WORKING_STATUSES = %w[active probation].freeze

    def self.run_for_all_tenants
      Tenant.where(status: %w[trial active]).find_each do |tenant|
        ActsAsTenant.with_tenant(tenant) do
          new(tenant: tenant).call
        end
      end
    end

    def initialize(tenant:, opening_on: Date.current)
      @tenant = tenant
      @opening_on = opening_on.to_date
    end

    def call
      ActsAsTenant.with_tenant(@tenant) { process_balances }
    end

    private

    def process_balances
      leave_types = LeaveType.active.paid.to_a
      return if leave_types.empty?

      opening_year = @opening_on.month >= 4 ? @opening_on.year : @opening_on.year - 1
      current_fy = "#{opening_year - 1}-#{opening_year.to_s.last(2)}"
      new_fy = "#{opening_year}-#{(opening_year + 1).to_s.last(2)}"
      now        = Time.current

      Employee.where(employment_status: WORKING_STATUSES).in_batches(of: 100) do |batch|
        working_ids = batch.pluck(:id)
        current_balances = LeaveBalance
          .where(financial_year: current_fy, employee_id: working_ids)
          .index_by { |b| [ b.employee_id, b.leave_type_id ] }

        # Employees who chose encashment — their carry-forward days become 0
        approved_encashments = LeaveEncashmentRequest
          .where(financial_year: current_fy, status: [ :approved, :paid ], employee_id: working_ids)
          .pluck(:employee_id, :leave_type_id)
          .to_set

        records = working_ids.flat_map do |employee_id|
          leave_types.map do |leave_type|
            current = current_balances[[ employee_id, leave_type.id ]]
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
    end

    def carried_days(leave_type, current_balance)
      return 0.0 unless leave_type.carry_forward? && current_balance
      [ leave_type.max_carry_forward, current_balance.remaining_days ].min.to_f
    end
  end
end
