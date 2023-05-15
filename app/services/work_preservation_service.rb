# frozen_string_literal: true

# A service to query an S3 bucket for information about a given data set
# rubocop:disable Metrics/ClassLength
class WorkPreservationService

  def initialize(work)
    @work = work
  end

  def metadata_io
    StringIO.new(@work.to_json)
  end

  def datacite_io
    StringIO.new(@work.to_xml)
  end

  def preservation_directory
    Pathname.new(@work.s3_query_service.prefix).join("princeton_data_commons/")
  end

  def bucket_name
    @work.s3_query_service.bucket_name
  end

  def s3_client
    @work.s3_query_service.client
  end

  def create_preservation_directory
    s3_client.put_object({ bucket: bucket_name, key: preservation_directory.to_s, content_length: 0 })
  end

  def upload_file(io:, filename:)
    md5_digest = @work.s3_query_service.md5(io:)
    key = preservation_directory.join(filename).to_s
    s3_client.put_object(bucket: bucket_name, key: key, body: io, content_md5: md5_digest)
    key
  end

  def preserve!
    raise "Cannot preserve work #{@work.id} because it has not been approved" unless @work.approved?
    byebug
    create_preservation_directory
    upload_file(io: metadata_io, filename: "metadata.json")
    upload_file(io: datacite_io, filename: "datacite.xml")
    preservation_directory
  end
end
# rubocop:enable Metrics/ClassLength
