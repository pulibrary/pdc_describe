# frozen_string_literal: true
module PdcDescribe
  class Application < Rails::Application
    config.provenance_message_writers = config_for(:provenance_message_writers)
  end
end
