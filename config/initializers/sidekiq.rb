Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }

  config.on(:startup) do
    Sidekiq::Cron::Job.create(
      name:  "Monthly Leave Accrual — 1st of every month",
      cron:  "0 0 1 * *",
      class: "Leave::MonthlyLeaveAccrualJob"
    )
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }
end
