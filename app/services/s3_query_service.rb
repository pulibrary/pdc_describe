# frozen_string_literal: true

require "aws-sdk-s3"

# A service to query an S3 bucket for information about a given data set
# rubocop:disable Metrics/ClassLength
class S3QueryService
  attr_reader :model

  def self.configuration
    Rails.configuration.s3
  end

  def self.pre_curation_config
    configuration.pre_curation
  end

  def self.post_curation_config
    configuration.post_curation
  end

  ##
  # @param [Work] model
  # @param [Boolean] pre_curation
  # @example S3QueryService.new(Work.find(1), true)
  def initialize(model, pre_curation = true)
    @model = model
    @doi = model.doi
    @pre_curation = pre_curation
  end

  def config
    return self.class.post_curation_config if post_curation?

    self.class.pre_curation_config
  end

  def pre_curation?
    @pre_curation
  end

  def post_curation?
    !pre_curation?
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
    signer = Aws::S3::Presigner.new(client: client)
    signer.presigned_url(:get_object, bucket: bucket_name, key: key)
  end

  def delete_file(key)
    client.delete_object({ bucket: bucket_name, key: key })
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
    @client ||= Aws::S3::Client.new(region: region, credentials: credentials)
  end

  # Retrieve the S3 resources attached to the Work model
  # @return [Array<S3File>]
  def model_s3_files
    objects = []
    return objects if model.nil?

    model_uploads.each do |attachment|
      s3_file = S3File.new(query_service: self,
                           filename: attachment.key,
                           last_modified: attachment.created_at,
                           size: attachment.byte_size,
                           checksum: attachment.checksum)
      objects << s3_file
    end

    objects
  end

  def get_s3_object(key:)
    response = client.get_object({
                                   bucket: bucket_name,
                                   key: key
                                 })
    object = response.to_h
    return if object.empty?

    object
  end

  def find_s3_file(filename:)
    s3_object_key = "#{prefix}#{filename}"

    object = get_s3_object(key: s3_object_key)
    return if object.nil?

    S3File.new(query_service: self, filename: s3_object_key, last_modified: object[:last_modified], size: object[:content_length], checksum: object[:etag])
  end

  # Retrieve the S3 resources uploaded to the S3 Bucket
  # @return [Array<S3File>]
  def client_s3_files(reload: false)
    @client_s3_files = nil if reload # force a reload
    @client_s3_files ||= begin
      start = Time.now
      resp = client.list_objects_v2({ bucket: bucket_name, max_keys: 1000, prefix: prefix })
      resp_hash = resp.to_h
      objects = parse_objects(resp_hash)
      objects += parse_continuation(resp_hash)
      elapsed = Time.now - start
      Rails.logger.info("Loading S3 objects. Bucket: #{bucket_name}. Prefix: #{prefix}. Elapsed: #{elapsed} seconds")
      objects
    end
  end

  def file_count
    client_s3_files.count
  end

  # TODO: delete this (or client_s3_files)
  def s3_files
    client_s3_files
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
    { objects: s3_files, ok: true }
  rescue => ex
    Rails.logger.error("Error querying S3. Bucket: #{bucket_name}. DOI: #{@doi}. Exception: #{ex.message}")

    { objects: [], ok: false }
  end

  ##
  # Copies the existing files from the pre-curation bucket to the post-curation bucket.
  # Notice that the copy process happens at AWS (i.e. the files are not downloaded and re-uploaded).
  # Returns an array with the files that were copied.
  def publish_files
    files = []
    source_bucket = S3QueryService.pre_curation_config[:bucket]
    target_bucket = S3QueryService.post_curation_config[:bucket]
    model.pre_curation_uploads.each do |file|
      params = {
        copy_source: "/#{source_bucket}/#{file.key}",
        bucket: target_bucket,
        key: file.key
      }
      Rails.logger.info("Copying #{params[:copy_source]} to #{params[:bucket]}/#{params[:key]}")
      client.copy_object(params)
      files << file
    end
    files
  end

  def delete_s3_object(s3_file_key)
    resp = client.delete_object({ bucket: bucket_name, key: s3_file_key })
    resp.to_h
  end

  private

    def model_uploads
      if pre_curation?
        client_s3_files
      else
        []
      end
    end

    def parse_objects(resp)
      objects = []
      resp_hash = resp.to_h
      response_objects = resp_hash[:contents]
      response_objects&.each do |object|
        next if object[:size] == 0 # ignore directories whose size is zero
        s3_file = S3File.new(query_service: self, filename: object[:key], last_modified: object[:last_modified], size: object[:size], checksum: object[:etag])
        objects << s3_file
      end
      objects
    end

    def parse_continuation(resp_hash)
      objects = []
      while resp_hash[:is_truncated]
        token = resp_hash[:next_continuation_token]
        resp = client.list_objects_v2({ bucket: bucket_name, max_keys: 1000, prefix: prefix, continuation_token: token })
        resp_hash = resp.to_h
        objects += parse_objects(resp_hash)
      end
      objects
    end
end
# rubocop:enable Metrics/ClassLength
