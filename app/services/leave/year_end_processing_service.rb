module Leave
  # Runs at financial year close (April 1st, 1am) to roll over leave balances.
  # For each active/probation employee:
  #   - carry_forward leave types: carries min(max_carry_forward, remaining_days) into new FY
  #   - non-carry-forward types: new FY starts fresh
  # New FY balance is seeded with April's monthly accrual already included so the
  # monthly accrual explicitly skips April to avoid crediting it twice.
  class YearEndProcessingService
    WORKING_STATUSES = Employee::IN_SERVICE_STATUSES

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
      ActsAsTenant.with_tenant(@tenant) { @tenant.with_lock { process_balances } }
    end

    private

    def process_balances
      leave_types = LeaveType.active.paid.to_a
      return if leave_types.empty?

      opening_year = FinancialYear.start_year(@opening_on)
      current_fy = FinancialYear.label_for_start_year(opening_year - 1)
      new_fy = FinancialYear.label_for_start_year(opening_year)
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
            first_month = AccrualAmount.for(leave_type, Date.new(opening_year, 4, 1))
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

        records.each do |attributes|
          key = attributes.slice(:employee_id, :leave_type_id, :financial_year)
          LeaveAuditContext.set(kind: "rollover", reason: "Financial year opening #{new_fy}") do
            LeaveBalance.find_or_create_by!(key) { |balance| balance.assign_attributes(attributes) }
          end
        end
      end
    end

    def carried_days(leave_type, current_balance)
      return 0.0 unless leave_type.carry_forward? && current_balance
      [ leave_type.max_carry_forward, current_balance.remaining_days ].min.to_f
    end
  end
end
