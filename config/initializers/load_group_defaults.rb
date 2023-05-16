# frozen_string_literal: true
module PdcDescribe
  class Application < Rails::Application
    config.group_defaults = config_for(:group_defaults)
  end
end
