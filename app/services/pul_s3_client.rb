# frozen_string_literal: true

require "aws-sdk-s3"

# A service to connect to an S3 bucket for information
class PULS3Client
  # Mode options
  PRECURATION = "precuration"
  POSTCURATION = "postcuration"
  PRESERVATION = "preservation"
  EMBARGO = "embargo"

  attr_reader :part_size, :last_response, :bucket_name

  ##
  # @param [String] mode See constant options above
  #                      This value controls the AWS S3 bucket used to access the files.
  # @param [String] "optional bucket name to override the bucket name defined by the mode"
  # @example S3Client.new("precuration")
  # @example S3Client.new(bucket_name: "example-bucket-two")
  #
  # See config/s3.yml for configuration file.
  def initialize(mode = "precuration", bucket_name: nil)
    @mode = mode
    @part_size = 5_368_709_120 # 5GB is the maximum part size for AWS
    @bucket_name = bucket_name || config.fetch(:bucket, nil)
  end

  class << self
    def configuration
      Rails.configuration.s3
    end

    def pre_curation_config
      configuration.pre_curation
    end

    def post_curation_config
      configuration.post_curation
    end

    def preservation_config
      configuration.preservation
    end

    def embargo_config
      configuration.embargo
    end
  end

  def config
    if @mode == PRESERVATION
      self.class.preservation_config
    elsif @mode == POSTCURATION
      self.class.post_curation_config
    elsif @mode == PRECURATION
      self.class.pre_curation_config
    elsif @mode == EMBARGO
      self.class.embargo_config
    else
      raise ArgumentError, "Invalid mode value: #{@mode}"
    end
  end

  def pre_curation?
    @mode == PRECURATION
  end

  def post_curation?
    @mode == POSTCURATION
  end

  def region
    config.fetch(:region, nil)
  end

  def access_key_id
    self.class.configuration["access_key_id"]
  end

  def secret_access_key
    self.class.configuration["secret_access_key"]
  end

  def credentials
    @credentials ||= Aws::Credentials.new(access_key_id, secret_access_key)
  end

  def client
    @client ||= Aws::S3::Client.new(region:, credentials:)
  end

  def upload_file(io:, target_key:, size:, md5_digest: nil)
    # upload file from io in a single request, may not exceed 5GB
    if size > part_size
      upload_multipart_file(target_key:, size:, io:)
    else
      md5_digest ||= md5(io:)
      @last_response = client.put_object(bucket: bucket_name, key: target_key, body: io, content_md5: md5_digest)
    end
    target_key
  rescue Aws::S3::Errors::SignatureDoesNotMatch => e
    Honeybadger.notify("Error Uploading file #{target_key} for object: s3://#{bucket_name}/ Signature did not match! error: #{e}")
    false
  rescue Aws::Errors::ServiceError => aws_service_error
    message = "An error was encountered when requesting to create the AWS S3 Object in the bucket #{bucket_name} with the key #{target_key}: #{aws_service_error}"
    Rails.logger.error(message)
    raise aws_service_error
  end

  private

    def upload_multipart_file(target_key:, size:, io:)
      multi = client.create_multipart_upload(bucket: bucket_name, key: target_key)
      part_num = 0
      start_byte = 0
      parts = []
      while start_byte < size
        part_num += 1
        parts << upload_part(part_num, io, multi)
        start_byte += part_size
      end
      @last_response = client.complete_multipart_upload(bucket: bucket_name, key: target_key, upload_id: multi.upload_id, multipart_upload: { parts: })
      true
    rescue Aws::Errors::ServiceError => aws_service_error
      message = "An error was encountered when requesting to multipart upload to AWS S3 Object to #{target_key} in the bucket #{target_bucket}: #{aws_service_error}"
      Rails.logger.error(message)
      raise aws_service_error
    end

    def upload_part(part_num, io, multi_upload)
      result = {}
      Tempfile.open("mutlipart-upload") do |file|
        IO.copy_stream(io, file, part_size)
        file.rewind
        checksum = md5(io: file)
        resp = client.upload_part(body: file, bucket: bucket_name, key: multi_upload.key, part_number: part_num, upload_id: multi_upload.upload_id, content_md5: checksum)
        result = { etag: resp.etag, part_number: part_num }
      end
      result
    end

    def md5(io:)
      md5 = Digest::MD5.new
      io.each(10_000) { |block| md5.update block }
      io.rewind
      md5.base64digest
    end
end
