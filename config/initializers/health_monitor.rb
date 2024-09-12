# frozen_string_literal: true
HealthMonitor.configure do |config|
  config.cache
  config.redis

  # Make this health check available at /health
  config.path = :health

  config.sidekiq.configure do |sidekiq_config|
    sidekiq_config.latency = 12.hours
    sidekiq_config.queue_size = 20_000
    sidekiq_config.maximum_amount_of_retries = 999_999 # this is really large becuase we don't really want to take the server out of rotation for this
  end

  config.error_callback = proc do |e|
    Rails.logger.error "Health check failed with: #{e.message}"
    Honeybadger.notify(e)
  end
end
