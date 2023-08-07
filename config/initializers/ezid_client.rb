# frozen_string_literal: true

Ezid::Client.configure do |config|
  config.default_shoulder = ENV["EZID_DEFAULT_SHOULDER"] || "ark:/99999/fk4"
  config.user = ENV["EZID_USER"] || "apitest"
  config.password = ENV["EZID_PASSWORD"] || "apitest"
  config.retry_interval = ENV["EZID_RETRY_INTERVAL"] || 1
end
