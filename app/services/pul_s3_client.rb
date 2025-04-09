# frozen_string_literal: true

require "aws-sdk-s3"

# A service to connect to an S3 bucket for information
class PULS3Client
  # Mode options
  PRECURATION = "precuration"
  POSTCURATION = "postcuration"
  PRESERVATION = "preservation"
  EMBARGO = "embargo"

  ##
  # @param [String] mode See constant options above
  #                      This value controls the AWS S3 bucket used to access the files.
  # @example S3Client.new("precuration")
  def initialize(mode = "precuration")
    @mode = mode
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

  ##
  # The name of the bucket this class is configured to use.
  # See config/s3.yml for configuration file.
  def bucket_name
    config.fetch(:bucket, nil)
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
end
