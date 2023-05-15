# frozen_string_literal: true

if Rails.env.staging? || Rails.env.production?
  Datadog.configure do |c|
    c.service = "pdc-describe"
    c.tracing.report_hostname = true
    c.tracing.analytics.enabled = true
    c.tracing.enabled = true
    c.tracing.report_hostname = true

    # Rails
    c.use :rails

    # Redis
    c.use :redis

    # Net::HTTP
    c.use :http

    # Sidekiq
    c.use :sidekiq

    # Faraday
    c.use :faraday
    # Add additional configuration here.
    # Activate integrations, change tracer settings, etc...
  end
end
