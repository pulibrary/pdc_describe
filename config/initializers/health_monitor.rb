# frozen_string_literal: true
HealthMonitor.configure do |config|
  config.cache
  config.redis
  config.sidekiq

  # Make this health check available at /health
  config.path = :health

  config.sidekiq.configure do |sidekiq_config|
    sidekiq_config.latency = 3.hours
  end

  config.error_callback = proc do |e|
    Rails.logger.error "Health check failed with: #{e.message}"
    Honeybadger.notify(e)
  end
end
