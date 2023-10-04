# frozen_string_literal: true

require "aws-sdk-s3"

# A service to query an S3 bucket for information about a given data set
# rubocop:disable Metrics/ClassLength
class S3QueryService
  attr_reader :model

  PRECURATION = "precuration"
  POSTCURATION = "postcuration"
  PRESERVATION = "preservation"

  def self.configuration
    Rails.configuration.s3
  end

  def self.pre_curation_config
    configuration.pre_curation
  end

  def self.post_curation_config
    configuration.post_curation
  end

  def self.preservation_config
    configuration.preservation
  end

  attr_reader :part_size, :last_response

  ##
  # @param [Work] model
  # @param [String] mode Valid values are "precuration", "postcuration", "preservation".
  #                      This value controlls the AWS S3 bucket used to access the files.
  # @example S3QueryService.new(Work.find(1), "precuration")
  def initialize(model, mode = "precuration")
    @model = model
    @doi = model.doi
    @mode = mode
    @part_size = 5_368_709_120 # 5GB is the maximum part size for AWS
    @last_response = nil
  end

  def config
    if @mode == PRESERVATION
      self.class.preservation_config
    elsif @mode == POSTCURATION
      self.class.post_curation_config
    elsif @mode == PRECURATION
      self.class.pre_curation_config
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

  ##
  # The name of the bucket this class is configured to use.
  # See config/s3.yml for configuration file.
  def bucket_name
    config.fetch(:bucket, nil)
  end

  def region
    config.fetch(:region, nil)
  end

  ##
  # The S3 prefix for this object, i.e., the address within the S3 bucket,
  # which is based on the DOI
  def prefix
    "#{@doi}/#{model.id}/"
  end

  ##
  # Construct an S3 address for this data set
  def s3_address
    "s3://#{bucket_name}/#{prefix}"
  end

  ##
  # Public signed URL to fetch this file from the S3 (valid for a limited time)
  def file_url(key)
    signer = Aws::S3::Presigner.new(client:)
    signer.presigned_url(:get_object, bucket: bucket_name, key:)
  end

  # There is probably a better way to fetch the current ActiveStorage configuration but we have
  # not found it.
  def active_storage_configuration
    Rails.configuration.active_storage.service_configurations[Rails.configuration.active_storage.service.to_s]
  end

  def access_key_id
    active_storage_configuration["access_key_id"]
  end

  def secret_access_key
    active_storage_configuration["secret_access_key"]
  end

  def credentials
    @credentials ||= Aws::Credentials.new(access_key_id, secret_access_key)
  end

  def client
    @client ||= Aws::S3::Client.new(region:, credentials:)
  end

  # required, accepts ETag, Checksum, ObjectParts, StorageClass, ObjectSize
  def self.object_attributes
    [
      "ETag",
      "Checksum",
      "ObjectParts",
      "StorageClass",
      "ObjectSize"
    ]
  end

  def get_s3_object_attributes(key:)
    response = client.get_object_attributes({
                                              bucket: bucket_name,
                                              key:,
                                              object_attributes: self.class.object_attributes
                                            })
    response.to_h
  end

  def get_s3_object(key:)
    response = client.get_object({
                                   bucket: bucket_name,
                                   key:
                                 })
    object = response.to_h
    return if object.empty?

    object
  rescue Aws::Errors::ServiceError => aws_service_error
    message = "An error was encountered when requesting the AWS S3 Object #{key}: #{aws_service_error}"
    Rails.logger.error(message)
    raise aws_service_error
  end

  def build_s3_object_key(filename:)
    "#{prefix}#{filename}"
  end

  def find_s3_file(filename:)
    s3_object_key = build_s3_object_key(filename:)

    object = get_s3_object_attributes(key: s3_object_key)
    return if object.nil?

    S3File.new(work: model, filename: s3_object_key, last_modified: object[:last_modified], size: object[:object_size], checksum: object[:etag])
  end

  # Retrieve the S3 resources uploaded to the S3 Bucket
  # @return [Array<S3File>]
  def client_s3_files(reload: false, bucket_name: self.bucket_name, prefix: self.prefix, ignore_directories: true)
    @client_s3_files = nil if reload # force a reload
    @client_s3_files ||= begin
      start = Time.zone.now
      resp = client.list_objects_v2({ bucket: bucket_name, max_keys: 1000, prefix: })
      resp_hash = resp.to_h
      objects = parse_objects(resp_hash, ignore_directories:)
      objects += parse_continuation(resp_hash, bucket_name:, prefix:, ignore_directories:)
      elapsed = Time.zone.now - start
      Rails.logger.info("Loading S3 objects. Bucket: #{bucket_name}. Prefix: #{prefix}. Elapsed: #{elapsed} seconds")
      objects
    end
  end

  def file_count
    client_s3_files.count
  rescue Aws::Errors::ServiceError => aws_service_error
    message = "An error was encountered when requesting AWS S3 Objects from the bucket #{bucket_name} with the prefix #{prefix}: #{aws_service_error}"
    Rails.logger.error(message)
    raise aws_service_error
  end

  ##
  # Query the S3 bucket for what we know about the doi
  # For docs see:
  # * https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Client.html#list_objects_v2-instance_method
  # * https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Client.html#get_object_attributes-instance_method
  # @return Hash with two properties {objects: [<S3File>], ok: Bool}
  #   objects is an Array of S3File objects
  #   ok is false if there is an error connecting to S3. Otherwise true.
  def data_profile
    { objects: client_s3_files, ok: true }
  rescue => ex
    Rails.logger.error("Error querying S3. Bucket: #{bucket_name}. DOI: #{@doi}. Exception: #{ex.message}")

    { objects: [], ok: false }
  end

  ##
  # Copies the existing files from the pre-curation bucket to the post-curation bucket.
  # Notice that the copy process happens at AWS (i.e. the files are not downloaded and re-uploaded).
  # Returns an array with the files that were copied.
  def publish_files(current_user)
    source_bucket = S3QueryService.pre_curation_config[:bucket]
    target_bucket = S3QueryService.post_curation_config[:bucket]
    files = client_s3_files(reload: true, bucket_name: source_bucket)
    snapshot = ApprovedUploadSnapshot.new(work: model)
    snapshot.store_files(files, current_user:)
    snapshot.save
    files.each do |file|
      ApprovedFileMoveJob.perform_later(work_id: model.id, source_bucket:, source_key: file.key, target_bucket:,
                                        target_key: file.key, size: file.size, snapshot_id: snapshot.id)
    end
    true
  end

  def copy_file(source_key:, target_bucket:, target_key:, size:)
    Rails.logger.info("Copying #{source_key} to #{target_bucket}/#{target_key}")
    if size > part_size
      copy_multi_part(source_key:, target_bucket:, target_key:, size:)
    else
      client.copy_object(copy_source: source_key, bucket: target_bucket, key: target_key, checksum_algorithm: "SHA256")
    end
  rescue Aws::Errors::ServiceError => aws_service_error
    message = "An error was encountered when requesting to copy AWS S3 Object from #{source_key} to #{target_key} in the bucket #{target_bucket}: #{aws_service_error}"
    Rails.logger.error(message)
    raise aws_service_error
  end

  def copy_multi_part(source_key:, target_bucket:, target_key:, size:)
    multi = client.create_multipart_upload(bucket: target_bucket, key: target_key, checksum_algorithm: "SHA256")
    part_num = 0
    start_byte = 0
    parts = []
    while start_byte < size
      part_num += 1
      end_byte = [start_byte + part_size, size].min - 1
      resp = client.upload_part_copy(bucket: target_bucket, copy_source: source_key, key: multi.key, part_number: part_num,
                                     upload_id: multi.upload_id, copy_source_range: "bytes=#{start_byte}-#{end_byte}")
      parts << { etag: resp.copy_part_result.etag, part_number: part_num, checksum_sha256: resp.copy_part_result.checksum_sha256 }
      start_byte = end_byte + 1
    end
    client.complete_multipart_upload(bucket: target_bucket, key: target_key, upload_id: multi.upload_id, multipart_upload: { parts: })
  rescue Aws::Errors::ServiceError => aws_service_error
    message = "An error was encountered when requesting to multipart copy AWS S3 Object from #{source_key} to #{target_key} in the bucket #{target_bucket}: #{aws_service_error}"
    Rails.logger.error(message)
    raise aws_service_error
  end

  def copy_directory(source_key:, target_bucket:, target_key:)
    client.copy_object(copy_source: source_key, bucket: target_bucket, key: target_key)
  rescue Aws::Errors::ServiceError => aws_service_error
    message = "An error was encountered when requesting to copy the AWS S3 directory Object from #{source_key} to #{target_key} in the bucket #{target_bucket}: #{aws_service_error}"
    Rails.logger.error(message)
    raise aws_service_error
  end

  def delete_s3_object(s3_file_key, bucket: bucket_name)
    resp = client.delete_object({ bucket:, key: s3_file_key })
    resp.to_h
  rescue Aws::Errors::ServiceError => aws_service_error
    message = "An error was encountered when requesting to delete the AWS S3 Object #{s3_file_key} in the bucket #{bucket_name}: #{aws_service_error}"
    Rails.logger.error(message)
    raise aws_service_error
  end

  def create_directory
    client.put_object({ bucket: bucket_name, key: prefix, content_length: 0 })
  rescue Aws::Errors::ServiceError => aws_service_error
    message = "An error was encountered when requesting to create the AWS S3 directory Object in the bucket #{bucket_name} with the key #{prefix}: #{aws_service_error}"
    Rails.logger.error(message)
    raise aws_service_error
  end

  def upload_file(io:, filename:, size:, md5_digest: nil)
    # upload file from io in a single request, may not exceed 5GB
    key = "#{prefix}#{filename}"
    if size > part_size
      upload_multipart_file(target_bucket: bucket_name, target_key: key, size:, io:)
    else
      md5_digest ||= md5(io:)
      @last_response = client.put_object(bucket: bucket_name, key:, body: io, content_md5: md5_digest)
    end
    key
  rescue Aws::S3::Errors::SignatureDoesNotMatch => e
    Honeybadger.notify("Error Uploading file #{filename} for object: #{s3_address} Signature did not match! error: #{e}")
    false
  rescue Aws::Errors::ServiceError => aws_service_error
    message = "An error was encountered when requesting to create the AWS S3 Object in the bucket #{bucket_name} with the key #{key}: #{aws_service_error}"
    Rails.logger.error(message)
    raise aws_service_error
  end

  def check_file(bucket:, key:)
    client.head_object({ bucket:, key: })
  rescue Aws::Errors::ServiceError => aws_service_error
    message = "An error was encountered when requesting to check the status of the AWS S3 Object in the bucket #{bucket} with the key #{key}: #{aws_service_error}"
    Rails.logger.error(message)
    raise aws_service_error
  end

  def md5(io:)
    md5 = Digest::MD5.new
    io.each(10_000) { |block| md5.update block }
    io.rewind
    md5.base64digest
  end

  private

    def parse_objects(resp, ignore_directories: true)
      objects = []
      resp_hash = resp.to_h
      response_objects = resp_hash[:contents]
      response_objects&.each do |object|
        next if object[:size] == 0 && ignore_directories
        s3_file = S3File.new(work: model, filename: object[:key], last_modified: object[:last_modified], size: object[:size], checksum: object[:etag])
        objects << s3_file
      end
      objects
    end

    def parse_continuation(resp_hash, bucket_name: self.bucket_name, prefix: self.prefix, ignore_directories: true)
      objects = []
      while resp_hash[:is_truncated]
        token = resp_hash[:next_continuation_token]
        resp = client.list_objects_v2({ bucket: bucket_name, max_keys: 1000, prefix:, continuation_token: token })
        resp_hash = resp.to_h
        objects += parse_objects(resp_hash, ignore_directories:)
      end
      objects
    rescue Aws::Errors::ServiceError => aws_service_error
      message = "An error was encountered when requesting to list the AWS S3 Objects in the bucket #{bucket_name} with the key #{prefix}: #{aws_service_error}"
      Rails.logger.error(message)
      raise aws_service_error
    end

    def upload_multipart_file(target_bucket:, target_key:, size:, io:)
      multi = client.create_multipart_upload(bucket: target_bucket, key: target_key)
      part_num = 0
      start_byte = 0
      parts = []
      while start_byte < size
        part_num += 1
        Tempfile.open("mutlipart-upload") do |file|
          IO.copy_stream(io, file, part_size)
          file.rewind
          checksum = md5(io: file)
          resp = client.upload_part(body: file, bucket: target_bucket, key: multi.key, part_number: part_num, upload_id: multi.upload_id, content_md5: checksum)
          parts << { etag: resp.etag, part_number: part_num }
        end
        start_byte += part_size
      end
      @last_response = client.complete_multipart_upload(bucket: target_bucket, key: target_key, upload_id: multi.upload_id, multipart_upload: { parts: })
    rescue Aws::Errors::ServiceError => aws_service_error
      message = "An error was encountered when requesting to multipart upload to AWS S3 Object to #{target_key} in the bucket #{target_bucket}: #{aws_service_error}"
      Rails.logger.error(message)
      raise aws_service_error
    end
end
# rubocop:enable Metrics/ClassLength
