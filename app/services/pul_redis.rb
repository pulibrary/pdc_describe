# frozen_string_literal: true

require "health_monitor/providers/redis"

CONNECTION_POOL_SIZE = 1

class PULRedisException < StandardError; end

class PULRedis < HealthMonitor::Providers::Redis
  def check!
    check_values!
    check_max_used_memory!
  rescue RuntimeError => e
    raise PULRedisException, e.message
  end

  private

    def key
      random = rand(99_999)
      @key ||= ["health", request.try(:remote_ip), random].join(":")
    end
end
