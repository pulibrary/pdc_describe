# frozen_string_literal: true
module PdcDescribe
  class Application < Rails::Application
    config.super_admins = config_for(:super_admins)
  end
end
