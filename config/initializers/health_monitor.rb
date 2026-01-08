# frozen_string_literal: true
require_relative "redis_config"
require "pul_redis"
require "pul_cache"

HealthMonitor.configure do |config|
  config.no_database
  config.database.configure do |provider_config|
    provider_config.config_name = "primary"
  end

  # utilizing our own redis check so we do nothave key collisions
  config.add_custom_provider(PULRedis).configure do |provider_config|
    provider_config.url = RedisConfig.url
  end

  # Use our custom Cache checker instead of the default one
  config.add_custom_provider(PULCache).configure

  # Make this health check available at /health
  config.path = :health

  config.sidekiq.configure do |sidekiq_config|
    sidekiq_config.latency = 6.hours
    sidekiq_config.queue_size = 20_000
    sidekiq_config.maximum_amount_of_retries = 100
    sidekiq_config.critical = false
  end

  config.file_absence.configure do |file_config|
    file_config.filename = "/opt/pdc_describe/shared/remove-from-nginx"
  end

  config.error_callback = proc do |e|
    Rails.logger.error "Health check failed with: #{e.message}"
    Honeybadger.notify(e) unless e.is_a?(HealthMonitor::Providers::FileAbsenceException)
  end
end
