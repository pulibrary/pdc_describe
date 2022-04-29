# frozen_string_literal: true
module PdcDescribe
  class Application < Rails::Application
    config.collection_defaults = config_for(:collection_defaults)
  end
end
