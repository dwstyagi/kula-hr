module Payroll
  # Session lock serializes workers without retaining a transaction's entire batch history.
  class RunLock
    def self.with(id)
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        key = Zlib.crc32("payroll-run:#{id}") & 0x7FFFFFFF
        acquired = connection.select_value("SELECT pg_try_advisory_lock(7319, #{key})")
        return false unless acquired
        begin
          yield
          true
        ensure
          connection.execute("SELECT pg_advisory_unlock(7319, #{key})")
        end
      end
    end
  end
end
