# frozen_string_literal: true

# A service to create and store the preservation data for a given work.
# Currently it assumes this data will be stored in an AWS S3 bucket accessible with our AWS credentials.
# This preservation bucket is configured in our s3.yml file and we store it in a different availability region
# to make sure the data is properly distributed.
class WorkPreservationService
  PRESERVATION_DIRECTORY = "princeton_data_commons"

  # @param work_id [Integer] The ID of the work to preserve.
  # @param path [String] The path where the work will be preserved.
  # @param localhost [Bool] Set to true to preserve the files locally, i.e. not in AWS
  def initialize(work_id:, path:, localhost: false)
    @work = Work.find(work_id)
    @path = path
    @localhost = localhost
    @s3_query_service = nil
  end

  # Creates and stores the preservation files for the work.
  # @return [String] The AWS S3 path where the files were stored
  def preserve!
    create_preservation_directory
    preserve_file(io: metadata_io, filename: "metadata.json")
    preserve_file(io: datacite_io, filename: "datacite.xml")
    preserve_file(io: provenance_io, filename: "provenance.json")
    Rails.logger.info "Preservation files for work #{@work.id} saved to #{target_location}"
    target_location
  end

  def preservation_metadata
    # Always use the post-curation file list
    metadata = JSON.parse(@work.to_json(force_post_curation: true))
    # Make sure we don't include the preservation files as part of
    # the work's preservation metadata.
    metadata["files"] = metadata["files"].map do |file|
      if file["filename"].include?("/#{PRESERVATION_DIRECTORY}/")
        nil
      else
        file
      end
    end.compact
    metadata.to_json
  end

  private

    def local?
      @localhost
    end

    def target_location
      if local?
        "file://" + File.join(Dir.pwd, preservation_directory)
      else
        "s3://#{bucket_name}/#{preservation_directory}"
      end
    end

    def metadata_io
      StringIO.new(preservation_metadata)
    end

    def datacite_io
      StringIO.new(@work.to_xml)
    end

    def provenance_io
      StringIO.new(@work.work_activity.to_json)
    end

    def preservation_directory
      Pathname.new(@path).join("#{PRESERVATION_DIRECTORY}/")
    end

    def s3_query_service
      # TODO: account for embargoes
      @s3_query_service ||= S3QueryService.new(@work, "preservation")
    end

    def bucket_name
      s3_query_service.bucket_name
    end

    def create_preservation_directory
      if local?
        FileUtils.mkdir_p preservation_directory.to_s
      else
        s3_query_service.client.put_object({ bucket: bucket_name, key: preservation_directory.to_s, content_length: 0 })
      end
    end

    def preserve_file(io:, filename:)
      if local?
        save_local_file(io:, filename:)
      else
        upload_file(io:, filename:)
      end
    end

    def upload_file(io:, filename:)
      s3client = PULS3Client.new(PULS3Client::PRESERVATION)
      key = preservation_directory.join(filename).to_s
      s3client.upload_file(io:, target_key: key, size: io.length)
      key
    end

    def save_local_file(io:, filename:)
      full_filename = preservation_directory.join(filename).to_s
      File.open(full_filename, "w") do |file|
        file.puts(io.read)
      end
      full_filename
    end
end
