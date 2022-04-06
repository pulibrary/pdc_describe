# frozen_string_literal: true
module PdcDescribe
  class Application < Rails::Application
    config.superadmins = config_for(:superadmins)
  end
end
