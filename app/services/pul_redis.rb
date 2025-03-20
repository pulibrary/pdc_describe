# frozen_string_literal: true

require "health_monitor/providers/redis"

CONNECTION_POOL_SIZE = 1

class PULRedis < HealthMonitor::Providers::Redis
  private

    # Add a random number to the key so we do not collide with another machine
    def key
      random = rand(99)
      @key ||= ["health", request.try(:remote_ip), random].join(":")
    end
end
