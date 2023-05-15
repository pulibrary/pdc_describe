# frozen_string_literal: true

if Rails.env.staging? || Rails.env.production?
  require "datadog/statsd"
  require "ddtrace"

  Datadog.configure do |c|
    c.service = "pdc-describe"
    c.tracing.report_hostname = true
    c.tracing.analytics.enabled = true
    c.tracing.enabled = true
    c.tracing.report_hostname = true

    # From https://docs.datadoghq.com/tracing/metrics/runtime_metrics/ruby/
    # To enable runtime metrics collection, set `true`. Defaults to `false`
    # You can also set DD_RUNTIME_METRICS_ENABLED=true to configure this.
    c.runtime_metrics.enabled = true

    # Optionally, you can configure the DogStatsD instance used for sending runtime metrics.
    # DogStatsD is automatically configured with default settings if `dogstatsd-ruby` is available.
    # You can configure with host and port of Datadog agent; defaults to 'localhost:8125'.
    c.runtime_metrics.statsd = Datadog::Statsd.new
  end
end
