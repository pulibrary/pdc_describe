# frozen_string_literal: true
require "active_storage/blob"

RSpec.configure do |config|
  config.before(:each, humanizable_storage: true) do
    @active_storage_config = {
      "test" => {
        "service" => "HumanizedDisk",
        "root" => Rails.root.join("spec", "fixtures", "storage")
      }
    }
    @active_storage_test_registry = ActiveStorage::Service::Registry.new(@active_storage_config)
    @active_storage_default_registry = ActiveStorage::Blob.services
    ActiveStorage::Blob.services = @active_storage_test_registry
  end

  config.after(:each, humanizable_storage: true) do
    ActiveStorage::Blob.services = @active_storage_default_registry
  end
end
