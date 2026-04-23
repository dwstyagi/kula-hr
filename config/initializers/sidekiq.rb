Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }

  config.on(:startup) do
    Sidekiq::Cron::Job.create(
      name:  "Monthly Leave Accrual — 1st of every month",
      cron:  "0 0 1 * *",
      class: "Leave::MonthlyLeaveAccrualJob"
    )

    Sidekiq::Cron::Job.create(
      name:  "Year-End Leave Processing — April 1st",
      cron:  "0 1 1 4 *",
      class: "Leave::YearEndProcessingJob"
    )

    Sidekiq::Cron::Job.create(
      name:  "Leave Encashment Reminder — March 1st",
      cron:  "0 9 1 3 *",
      class: "Leave::EncashmentReminderJob"
    )

    Sidekiq::Cron::Job.create(
      name:  "Comp-Off Expiry — daily at midnight",
      cron:  "0 0 * * *",
      class: "Leave::CompOffExpiryJob"
    )
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }
end
