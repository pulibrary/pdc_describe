# frozen_string_literal: true
class S3File
  attr_accessor :filename, :last_modified, :size, :checksum
  alias key filename

  def initialize(filename:, last_modified:, size:, checksum:, query_service: nil)
    @filename = filename
    @last_modified = last_modified
    @size = size
    @checksum = checksum.delete('"')
    @query_service = query_service
  end

  def globus_url
    encoded_filename = filename.split("/").map { |name| CGI.escape(name) }.join("/")
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
