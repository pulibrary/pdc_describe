# frozen_string_literal: true
module PdcDescribe
  class Application < Rails::Application
    config.globus = config_for(:globus)
  end
end
