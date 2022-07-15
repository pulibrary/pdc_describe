# frozen_string_literal: true
require "active_storage/service/disk_service"

module ActiveStorage
  class Service::HumanizedDiskService < ActiveStorage::Service::DiskService
    def folder_for(key)
      segments = key.split("/")
      folder_segments = segments[0..-2]
      folder_segments.join("/")
    end

    def make_path_for(key)
      child_path = folder_for(key)
      folder_path = [root, child_path].join("/")
      FileUtils.mkdir_p(folder_path)

      segments = key.split("/")
      "#{folder_path}/#{segments.last}"
    end

    def path_for(key)
      segments = key.split("/")
      File.join(root, folder_for(key), segments.last)
    end

    def upload(key, io, checksum: nil, **options)
      return if exist?(key)

      super(key, io, checksum: checksum, **options)
    end
  end
end
