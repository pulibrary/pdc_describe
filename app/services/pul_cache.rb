# frozen_string_literal: true

require 'health_monitor/providers/cache'

class PULCacheException < StandardError; end

class PULCache < HealthMonitor::Providers::Cache
  def check!
    time = Time.now.to_formatted_s(:rfc2822)

    Rails.cache.write(key, time)
    fetched = Rails.cache.read(key)

    raise "different values (now: #{time}, fetched: #{fetched})" if fetched != time
  rescue Exception => e
    raise CacheException.new(e.message)
  end

  private

  def key
    random = rand(99_999)
    @key ||= ["health", request.try(:remote_ip), random].join(":")
  end
end