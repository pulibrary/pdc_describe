# frozen_string_literal: true
class S3File
  include Rails.application.routes.url_helpers
  include ActionView::Helpers::NumberHelper

  attr_accessor :safe_id, :filename, :last_modified, :size, :checksum, :url, :filename_display, :last_modified_display, :display_size, :is_folder
  alias key filename
  alias id filename

  def self.from_json(json_string)
    json = if json_string.is_a? String
             JSON.parse(json_string)
           else
             json_string
           end

    new(filename: json["filename"], last_modified: DateTime.parse(json["last_modified"]), size: json["size"],
        checksum: json["checksum"], work: Work.find(json["work_id"]), filename_display: json["filename_display"], url: json["url"])
  end

  def initialize(filename:, last_modified:, size:, checksum:, work:, filename_display: nil, url: nil)
    @safe_id = filename_as_id(filename)
    @filename = filename
    @filename_display = filename_display || filename_short(work, filename)
    @last_modified = last_modified
    @last_modified_display = last_modified.in_time_zone.strftime("%m/%d/%Y %I:%M %p") # mm/dd/YYYY HH:MM AM
    @size = size
    @display_size = number_to_human_size(size)
    @checksum = checksum.delete('"')
    @url = url || work_download_path(work, filename:)
    @work = work
    @is_folder = filename.ends_with?("/")
  end

  def created_at
    last_modified
  end

  def byte_size
    size
  end

  def directory?
    size == 0
  end

  def empty?
    size == 0
  end

  def globus_url
    encoded_filename = filename.split("/").map { |name| ERB::Util.url_encode(name) }.join("/")
    File.join(Rails.configuration.globus["post_curation_base_url"], encoded_filename)
  end

  delegate :s3_query_service, to: :@work
  delegate :bucket_name, to: :s3_query_service
  def s3_client
    s3_query_service.client
  end

  # Create a new snapshot of the current upload
  # @return [UploadSnapshot]
  def create_snapshot
    created = UploadSnapshot.create(url:, work: @work, files: [{ filename:, checksum: }])

    created.upload = self
    created.save
    created.reload
  end

  # @return [UploadSnapshot]
  def snapshots
    persisted = UploadSnapshot.where(key:, url:, work: @work)
    return [] if persisted.blank?

    persisted
  end

  def to_json
    {
      filename:, last_modified:, size:,
      checksum:, work_id: @work.id, filename_display:, url:
    }.to_json
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
