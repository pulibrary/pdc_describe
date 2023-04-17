# frozen_string_literal: true
module PdcDescribe
  class Application < Rails::Application
    config.dspace = config_for(:dspace)
  end
end
