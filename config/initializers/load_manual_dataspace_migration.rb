# frozen_string_literal: true
module PdcDescribe
  class Application < Rails::Application
    config.manual_dataspace_migration = config_for(:manual_dataspace_migration)
  end
end
