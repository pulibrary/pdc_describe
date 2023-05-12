# frozen_string_literal: true
Datadog.configure do |c|
  c.service = "pdc-describe"
  c.tracing.report_hostname = true
  c.tracing.analytics.enabled = true
  c.tracing.enabled = true
  c.tracing.report_hostname = true
  # Add additional configuration here.
  # Activate integrations, change tracer settings, etc...
end
