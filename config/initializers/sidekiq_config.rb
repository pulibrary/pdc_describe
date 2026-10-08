# frozen_string_literal: true
Sidekiq.configure_server do |config|
  config.redis = { url: RedisConfig.url }

  # Rails logs at :warn in staging and production, which drops the per-job
  # "Start #perform" / "Completed #perform" lines (queue latency and job duration)
  # that rails_semantic_logger writes for Sidekiq. Log at :info in the worker
  # process only, so the web logs stay quiet.
  SemanticLogger.default_level = ENV.fetch("SIDEKIQ_LOG_LEVEL", "info")
end

Sidekiq.configure_client do |config|
  config.redis = { url: RedisConfig.url }
end
