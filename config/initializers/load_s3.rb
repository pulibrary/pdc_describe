# frozen_string_literal: true
module PdcDescribe
  class Application < Rails::Application
    config.s3 = config_for(:s3)
  end
end
