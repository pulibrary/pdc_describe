# frozen_string_literal: true
HealthMonitor.configure do |config|
  config.cache
  config.redis

  # Make this health check available at /health
  config.path = :health

  config.sidekiq.configure do |sidekiq_config|
    sidekiq_config.latency = 6.hours
    sidekiq_config.queue_size = 10_000
    sidekiq_config.maximum_amount_of_retries = 100
    sidekiq_config.critical = false
  end

  config.error_callback = proc do |e|
    Rails.logger.error "Health check failed with: #{e.message}"
    Honeybadger.notify(e)
  end
end
