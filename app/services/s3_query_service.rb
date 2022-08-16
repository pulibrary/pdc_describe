# frozen_string_literal: true

require "aws-sdk-s3"

# A service to query an S3 bucket for information about a given data set
class S3QueryService
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
  def initialize(doi, pre_curation = true)
    @doi = doi
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

  def model
    @model ||= Work.find_by(doi: @doi)
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
    objects = []
    return objects if model.nil?

    model.uploads.each do |attachment|
      s3_file = S3File.new(filename: attachment.key, last_modified: attachment.created_at, size: attachment.byte_size)
      objects << s3_file
    end

    { objects: objects, ok: true }
  rescue => ex
    Rails.logger.error("Error querying S3. Bucket: #{bucket_name}. DOI: #{@doi}. Exception: #{ex.message}")

    { objects: [], ok: false }
  end
end
