# frozen_string_literal: true

require 'bytesize'

class S3File
  include Rails.application.routes.url_helpers

  attr_accessor :safe_id, :filename, :last_modified, :size, :checksum, :url, :filename_display, :last_modified_display
  alias key filename
  alias id filename

  def initialize(filename:, last_modified:, size:, checksum:, work:)
    @safe_id = filename_as_id(filename)
    @filename = filename
    @filename_display = filename_short(work, filename)
    @last_modified = last_modified
    @last_modified_display = last_modified.in_time_zone.strftime("%m/%d/%Y %I:%M %p") # mm/dd/YYYY HH:MM AM
    @size = size_display(size)
    @checksum = checksum.delete('"')
    @url = work_download_path(work, filename: filename)
    @work = work
  end

  def created_at
    last_modified
  end

  def byte_size
    ByteSize.new(size)
  end

  def size_display(size)
    ByteSize.new(size).to_s
  end 

  def directory?
    size == 0
  end

  def globus_url
    encoded_filename = filename.split("/").map { |name| ERB::Util.url_encode(name) }.join("/")
    File.join(Rails.configuration.globus["post_curation_base_url"], encoded_filename)
  end

  def create_blob(key: nil)
    key ||= filename
    params = { filename: filename, content_type: "", byte_size: size, checksum: checksum }

    blob = ActiveStorage::Blob.create_before_direct_upload!(**params)
    blob.key = key
    blob
  end

  def to_blob
    existing_blob = ActiveStorage::Blob.find_by(key: filename)

    if existing_blob.present?
      Rails.logger.warn("There is a blob existing for #{filename}, which we are not expecting!  It will be reattached #{existing_blob.inspect}")
      return existing_blob
    end

    create_blob
  end

  delegate :s3_query_service, to: :@work
  delegate :bucket_name, to: :s3_query_service
  def s3_client
    s3_query_service.client
  end

  # Create a new snapshot of the current upload
  # @return [UploadSnapshot]
  def create_snapshot
    created = UploadSnapshot.create(url: url, work: @work, files: [{ filename: filename, checksum: checksum }])

    created.upload = self
    created.save
    created.reload
  end

  # @return [UploadSnapshot]
  def snapshots
    persisted = UploadSnapshot.where(key: key, url: url, work: @work)
    return [] if persisted.blank?

    persisted
  end

  private

    # Filename without the DOI/work-id/ in the path (but we preserve other path information if there is any)
    def filename_short(work, filename)
      prefix = "#{work.doi}/#{work.id}/"
      if filename.start_with?(prefix)
        filename[prefix.length..]
      else
        filename
      end
    end

    def filename_as_id(filename)
      # The full filename and path but only with alphanumeric characters
      # everything else becomes as dash.
      filename.gsub(/[^A-Za-z\d]/, "-")
    end
end
