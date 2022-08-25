# frozen_string_literal: true

require "aws-sdk-s3"

# A service to query an S3 bucket for information about a given data set
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
  # @param [String] doi
  # @param [Boolean] pre_curation
  # @example S3QueryService.new("https://doi.org/10.34770/0q6b-cj27")
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

  def client
    credentials = Aws::Credentials.new(access_key_id, secret_access_key)
    @client ||= Aws::S3::Client.new(region: region, credentials: credentials)
  end

  # Retrieve the S3 resources attached to the Work model
  # @return [Array<S3File>]
  def model_s3_files
    objects = []
    return objects if model.nil?

    model.uploads.each do |attachment|
      s3_file = S3File.new(filename: attachment.key, last_modified: attachment.created_at, size: attachment.byte_size)
      objects << s3_file
    end

    objects
  end

  # Retrieve the S3 resources uploaded to the S3 Bucket
  # @return [Array<S3File>]
  def client_s3_files
    objects = []
    Rails.logger.debug("Bucket: #{bucket_name}")
    Rails.logger.debug("Prefix: #{prefix}")
    resp = client.list_objects_v2({ bucket: bucket_name, max_keys: 1000, prefix: prefix })
    response_objects = resp.to_h[:contents]
    Rails.logger.debug("Objects: #{response_objects}")
    response_objects&.each do |object|
      s3_file = S3File.new(filename: object[:key], last_modified: object[:last_modified], size: object[:size])
      objects << s3_file
    end

    objects
  end

  # Retrieve the S3 resources from the S3 Bucket without those attached to the Work model
  # @return [Array<S3File>]
  def s3_files
    model_s3_file_keys = model_s3_files.map(&:filename)
    client_s3_files.reject { |client_s3_file| model_s3_file_keys.include?(client_s3_file.filename) }
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
end
