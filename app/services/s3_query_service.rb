# frozen_string_literal: true

require "aws-sdk-s3"

# A service to query an S3 bucket for information about a given data set
# rubocop:disable Metrics/ClassLength
class S3QueryService
  attr_reader :model

  attr_reader :part_size, :last_response, :s3client

  delegate "pre_curation?", "post_curation?", :bucket_name, :region, :client, to: :s3client

  ##
  # @param [Work] model
  # @param [String] mode Valid values are PULS3Client::PRECURATION, PULS3Client::POSTCURATION
  #                          PULS3Client::PRESERVATION, and PULS3Client::EMBARGO.
  #                      This value controls the AWS S3 bucket used to access the files.
  # @example S3QueryService.new(Work.find(1), "precuration")
  def initialize(model, mode = PULS3Client::PRECURATION, bucket_name: nil)
    @model = model
    @doi = model.doi
    @s3client = PULS3Client.new(mode, bucket_name:)
    @part_size = 5_368_709_120 # 5GB is the maximum part size for AWS
    @last_response = nil
    @s3_responses = {}
  end

  ##
  # The S3 prefix for this object, i.e., the address within the S3 bucket,
  # which is based on the DOI
  def prefix
    "#{@doi}/#{model.id}/"
  end

  ##
  # Public signed URL to fetch this file from the S3 (valid for a limited time)
  def file_url(key)
    signer = Aws::S3::Presigner.new(client:)
    signer.presigned_url(:get_object, bucket: bucket_name, key:)
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

  # Retrieve the S3 resources uploaded to the S3 Bucket
  # @return [Array<S3File>]
  def client_s3_files(reload: false, bucket_name: self.bucket_name, prefix: self.prefix)
    if reload # force a reload
      @client_s3_files = nil
      clear_s3_responses(bucket_name:, prefix:)
    end
    @client_s3_files ||= get_s3_objects(bucket_name:, prefix:)
  end

  def client_s3_empty_files(reload: false, bucket_name: self.bucket_name, prefix: self.prefix)
    if reload # force a reload
      @client_s3_empty_files = nil
      clear_s3_responses(bucket_name:, prefix:)
    end
    @client_s3_empty_files ||= begin
      files_and_directories = get_s3_objects(bucket_name:, prefix:)
      files_and_directories.select(&:empty?)
    end
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
    source_bucket = PULS3Client.pre_curation_config[:bucket]
    target_bucket = PULS3Client.post_curation_config[:bucket]
    empty_files = client_s3_empty_files(reload: true, bucket_name: source_bucket)
    # Do not move the empty files, however, ensure that it is noted that the
    #   presence of empty files is specified in the provenance log.
    unless empty_files.empty?
      empty_files.each do |empty_file|
        message = "Warning: Attempted to publish empty S3 file #{empty_file.filename}."
        WorkActivity.add_work_activity(model.id, message, current_user.id, activity_type: WorkActivity::SYSTEM)
      end
    end

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
      client.copy_object(copy_source: source_key.gsub("+", "%2B"), bucket: target_bucket, key: target_key, checksum_algorithm: "SHA256")
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
    key = "#{prefix}#{filename}"
    if s3client.upload_file(io:, target_key: key, size:, md5_digest:)
      key
    end
  end

  def check_file(bucket:, key:)
    client.head_object({ bucket:, key: })
  rescue Aws::Errors::ServiceError => aws_service_error
    message = "An error was encountered when requesting to check the status of the AWS S3 Object in the bucket #{bucket} with the key #{key}: #{aws_service_error}"
    Rails.logger.error(message)
    raise aws_service_error
  end

  private

    def clear_s3_responses(bucket_name:, prefix:)
      key = "#{bucket_name} #{prefix}"
      @s3_responses[key] = nil
    end

    def s3_responses(bucket_name:, prefix:)
      key = "#{bucket_name} #{prefix}"
      responses = @s3_responses[key]
      if responses.nil?
        resp = client.list_objects_v2({ bucket: bucket_name, max_keys: 1000, prefix: })
        responses = [resp]
        while resp.is_truncated
          resp = client.list_objects_v2({ bucket: bucket_name, max_keys: 1000, prefix:, continuation_token: resp.next_continuation_token })
          responses << resp
        end
        @s3_responses[key] = responses
      end
      responses
    end

    def get_s3_objects(bucket_name:, prefix:)
      start = Time.zone.now
      responses = s3_responses(bucket_name:, prefix:)
      objects = responses.reduce([]) do |all_objects, resp|
        resp_hash = resp.to_h
        resp_objects = parse_objects(resp_hash)
        all_objects + resp_objects
      end
      elapsed = Time.zone.now - start
      Rails.logger.info("Loading S3 objects. Bucket: #{bucket_name}. Prefix: #{prefix}. Elapsed: #{elapsed} seconds")
      objects
    end

    def parse_objects(resp)
      objects = []
      resp_hash = resp.to_h
      response_objects = resp_hash[:contents]
      response_objects&.each do |object|
        s3_file = S3File.new(work: model, filename: object[:key], last_modified: object[:last_modified], size: object[:size], checksum: object[:etag])
        objects << s3_file
      end
      objects
    end
end
# rubocop:enable Metrics/ClassLength
