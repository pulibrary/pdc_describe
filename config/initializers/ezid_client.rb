# frozen_string_literal: true

Ezid::Client.configure do |config|
  config.default_shoulder = "ark:/99999/fk4" || ENV["EZID_DEFAULT_SHOULDER"]
  config.user = "apitest" || ENV["EZID_USER"]
  config.password = "apitest" || ENV["EZID_PASSWORD"]
  config.retry_interval = 1 || ENV["EZID_RETRY_INTERVAL"]
end
