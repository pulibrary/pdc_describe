# frozen_string_literal: true
require_relative "boot"

require "rails/all"
require_relative "lando_env"

# Require the gems listed in Gemfile,  but only the default ones
# and those for the environment rails is running in.
Bundler.require(:default, Rails.env)

module PdcDescribe
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.1

    if Rails.env.production? || Rails.env.staging?
      config.relative_url_root = "/describe"
    end

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
    Rails.application.routes.default_url_options = {
      host: ENV.fetch("APPLICATION_HOST", "localhost"),
      port: ENV.fetch("APPLICATION_PORT", "3000"),
      protocol: ENV.fetch("APPLICATION_HOST_PROTOCOL", "http")
    }

    # Explicitly set timezome rather than relying on system,
    # which may be different in CI environment.
    config.time_zone = "America/New_York"

    config.exceptions_app = routes
  end
end
