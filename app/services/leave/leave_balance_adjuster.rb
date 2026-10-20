module Leave
  # Debit rows preserve the financial years charged for exact cancellation.
  class LeaveBalanceAdjuster
    InsufficientBalance = Class.new(StandardError)

    def initialize(leave_request:)
      @request = leave_request
    end

    def debit!
      return if @request.leave_type.lop?

      @request.with_lock do
        next if @request.approved? || @request.leave_balance_debits.exists?

        allocations = @request.days_by_financial_year
        raise InsufficientBalance, "The leave dates no longer contain working days. Cancel this request and choose new dates." if allocations.empty?

        @request.update!(number_of_days: allocations.values.sum) if @request.number_of_days != allocations.values.sum
        allocations.sort.each do |financial_year, days|
          balance = balance_for(financial_year)
          raise InsufficientBalance, "No balance record found for #{@request.leave_type.name} in #{financial_year}" unless balance

          balance.with_lock do
            if balance.remaining_days < days
              raise InsufficientBalance, "Insufficient #{@request.leave_type.name} balance for #{financial_year}. #{balance.remaining_days} days remaining, #{days} requested."
            end
            consume_comp_off!(financial_year) if comp_off?
            balance.update!(used_days: balance.used_days + days, remaining_days: balance.remaining_days - days)
            @request.leave_balance_debits.create!(leave_balance: balance, number_of_days: days)
          end
        end
      end
    end

    def credit!
      return if @request.leave_type.lop?

      @request.with_lock do
        # Legacy approvals charged the balance for the year of approval.
        if !@request.leave_balance_debits.exists? && @request.approved?
          year = FinancialYear.label(@request.approved_at&.to_date || @request.from_date)
          balance = balance_for(year)
          @request.leave_balance_debits.create!(leave_balance: balance, number_of_days: @request.number_of_days) if balance
        end
        @request.leave_balance_debits.where(reversed_at: nil).order(:leave_balance_id).each do |debit|
          balance = debit.leave_balance
          balance.with_lock do
            days = [ debit.number_of_days, balance.used_days ].min
            expired = comp_off? ? restore_comp_off!(balance.financial_year, days) : 0
            balance.update!(used_days: balance.used_days - days,
              remaining_days: balance.remaining_days + days - expired,
              total_days: balance.total_days - expired)
            debit.update!(reversed_at: Time.current)
          end
        end
      end
    end

    private

    def balance_for(year)
      LeaveBalance.find_by(employee: @request.employee, leave_type: @request.leave_type, financial_year: year)
    end

    def comp_off? = @request.leave_type.code == "CO"

    def consume_comp_off!(financial_year)
      year_start = Date.new(financial_year.first(4).to_i, 4, 1)
      @request.daily_units.select { |date, _units| FinancialYear.label(date) == financial_year }.each do |date, units|
        unallocated = units
        while unallocated.positive?
          credit = CompOffRequest.approved.where(employee: @request.employee, balance_expired: false)
            .where("approved_at >= ?", year_start.beginning_of_day)
            .where("remaining_days > 0 AND expiry_date >= ?", date)
            .where("approved_at <= ?", date.end_of_day)
            .order(:expiry_date, :id).lock.first
          raise InsufficientBalance, "No unexpired comp-off credit is available for #{date}" unless credit

          consumed = [ credit.remaining_days, unallocated ].min
          credit.update!(remaining_days: credit.remaining_days - consumed)
          usage = @request.comp_off_usages.find_or_initialize_by(comp_off_request: credit)
          usage.number_of_days = (usage.number_of_days || 0) + consumed
          usage.save!
          unallocated -= consumed
        end
      end
    end

    def restore_comp_off!(financial_year, days)
      return restore_legacy_comp_off!(financial_year, days) if @request.comp_off_usages.empty?

      expired = 0
      @request.comp_off_usages.includes(:comp_off_request).each do |usage|
        credit = usage.comp_off_request
        next unless FinancialYear.label(credit.approved_at.to_date) == financial_year

        credit.with_lock do
          if credit.expiry_date < Date.current || credit.balance_expired?
            expired += usage.number_of_days
          else
            credit.update!(remaining_days: credit.remaining_days + usage.number_of_days)
          end
          usage.destroy!
        end
      end
      expired
    end

    # Legacy approvals have only an aggregate debit. Reverse FIFO consumption
    # against eligible credits; never create an unexpiring, unbacked credit.
    def restore_legacy_comp_off!(financial_year, days)
      year_start = Date.new(financial_year.first(4).to_i, 4, 1)
      unallocated = days
      expired = 0
      CompOffRequest.approved.where(employee: @request.employee)
        .where(approved_at: year_start.beginning_of_day...year_start.next_year.beginning_of_day)
        .where("approved_at <= ?", @request.approved_at || @request.from_date.end_of_day)
        .where("remaining_days < 1 AND expiry_date >= ?", @request.from_date)
        .order(:expiry_date, :id).lock.each do |credit|
          restored = [ 1 - credit.remaining_days, unallocated ].min
          if credit.expiry_date < Date.current || credit.balance_expired?
            expired += restored
          else
            credit.update!(remaining_days: credit.remaining_days + restored)
          end
          unallocated -= restored
          break if unallocated.zero?
        end
      expired + unallocated
    end
  end
end
