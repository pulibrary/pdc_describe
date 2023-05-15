# frozen_string_literal: true

# A service to create and store the preservation data for a given work.
# Currently it assumes this data will be stored in an AWS S3 bucket accessible
# with our AWS credentials, but allows the bucket and path to be configurable.
class WorkPreservationService

  # @param work [Work] The work to preserve.
  # @param bucket_name [String] The AWS S3 bucket name where the work will be preserved.
  # @param path [String] The path where the work will be preserved, e.g.
  def initialize(work:, bucket_name: nil, path: nil)
    @work = work
    # Defaults to the post curation bucket, e.g. "pdc-describe-staging-postcuration"
    @bucket_name = bucket_name || @work.s3_query_service.bucket_name
    # Defaults to the DOI prefix + DOI + work.id, e.g. "10.1234/xy123/10/"
    @path = path || @work.s3_query_service.prefix
  end

  # Creates and stores the preservation files for the work.
  # @return [String] The AWS S3 path where the files were stored
  def preserve!
    raise StandardError.new("Cannot preserve work #{@work.id} because it has not been approved") unless @work.approved?
    create_preservation_directory
    upload_file(io: metadata_io, filename: "metadata.json")
    upload_file(io: datacite_io, filename: "datacite.xml")
    "s3://#{@bucket_name}/#{preservation_directory}"
  end

  private

    def metadata_io
      StringIO.new(@work.to_json)
    end

    def datacite_io
      StringIO.new(@work.to_xml)
    end

    def preservation_directory
      Pathname.new(@path).join("princeton_data_commons/")
    end

    def s3_client
      @work.s3_query_service.client
    end

    def create_preservation_directory
      s3_client.put_object({ bucket: @bucket_name, key: preservation_directory.to_s, content_length: 0 })
    end
    def upload_file(io:, filename:)
      md5_digest = @work.s3_query_service.md5(io:)
      key = preservation_directory.join(filename).to_s
      s3_client.put_object(bucket: @bucket_name, key: key, body: io, content_md5: md5_digest)
      key
    end
end
