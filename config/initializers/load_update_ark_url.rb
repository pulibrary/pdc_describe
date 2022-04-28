# frozen_string_literal: true
module PdcDescribe
  class Application < Rails::Application
    config.update_ark_url = config_for(:update_ark_url)
  end
end
