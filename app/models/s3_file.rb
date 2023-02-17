# frozen_string_literal: true
class S3File
  include Rails.application.routes.url_helpers

  attr_accessor :filename, :last_modified, :size, :checksum, :url
  alias key filename
  alias id filename

  def initialize(filename:, last_modified:, size:, checksum:, work:)
    @filename = filename
    @last_modified = last_modified
    @size = size
    @checksum = checksum.delete('"')
    @url = work_download_path(work, filename: filename)
  end

  def created_at
    last_modified
  end

  def byte_size
    size
  end

  def globus_url
    encoded_filename = filename.split("/").map { |name| ERB::Util.url_encode(name) }.join("/")
    File.join(Rails.configuration.globus["post_curation_base_url"], encoded_filename)
  end

  def to_blob
    existing_blob = ActiveStorage::Blob.find_by(key: filename)

    if existing_blob.present?
      Rails.logger.warn("There is a blob existing for #{filename}, which we are not expecting!  It will be reattached #{existing_blob.inspect}")
      return existing_blob
    end

    params = { filename: filename, content_type: "", byte_size: size, checksum: checksum }
    blob = ActiveStorage::Blob.create_before_direct_upload!(**params)
    blob.key = filename
    blob
  end
end
