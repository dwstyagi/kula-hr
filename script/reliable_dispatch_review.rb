# Run independently of RSpec: bundle exec rails runner -e test script/reliable_dispatch_review.rb
# Exercises real commits and independent PostgreSQL sessions, not fixture transactions.
raise "Test database required" unless Rails.env.test? && ActiveRecord::Base.connection_db_config.database == "hrms_test"

ActiveJob::Base.queue_adapter = :test
adapter = ActiveJob::Base.queue_adapter
id = -SecureRandom.random_number(1_000_000_000)
dispatch = nil
begin
  JobDispatch.transaction do
    dispatch = JobDispatch.enqueue!(BackgroundTaskJob, id)
    raise "Job published before commit" unless adapter.enqueued_jobs.empty?
  end
  raise "Job missing after commit" unless adapter.enqueued_jobs.size == 1
  visible = Thread.new do
    ActiveRecord::Base.connection_pool.with_connection { JobDispatch.exists?(dispatch.id) }
  end.value
  raise "Committed work invisible to worker" unless visible
  puts "PASS: dispatch waits for commit; separate worker connection sees durable work"

  yielded = false
  Payroll::RunLock.with(id) do
    acquired = Thread.new { Payroll::RunLock.with(id) { yielded = true } }.value
    raise "Duplicate worker entered payroll" if acquired || yielded
  end
  acquired = Thread.new { Payroll::RunLock.with(id) { yielded = true } }.value
  raise "Lock was not released" unless acquired && yielded
  puts "PASS: duplicate worker excluded; lock released for subsequent work"

  adapter.enqueued_jobs.clear
  begin
    JobDispatch.transaction do
      JobDispatch.enqueue!(BackgroundTaskJob, id - 1)
      raise ActiveRecord::Rollback
    end
    raise "Rolled-back work was published" unless adapter.enqueued_jobs.empty?
    puts "PASS: rollback never publishes a job"
  end
ensure
  JobDispatch.where("arguments = ?::jsonb OR arguments = ?::jsonb", [ id ].to_json, [ id - 1 ].to_json).delete_all
end
