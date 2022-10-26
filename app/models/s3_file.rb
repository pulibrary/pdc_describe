# frozen_string_literal: true
class S3File
  attr_accessor :filename, :last_modified, :size, :checksum
  alias key filename

  def initialize(filename:, last_modified:, size:, checksum:, query_service: nil)
    @filename = filename
    @last_modified = last_modified
    @size = size
    @checksum = checksum.delete('"')
    @query_service = query_service
  end

  # def bucket_name
  #   return if @query_service.nil?

  #   @query_service.bucket_name
  # end

  # def url_protocol
  #   return if @query_service.nil?

  #   @query_service.class.url_protocol
  # end

  # def s3_host
  #   return if @query_service.nil?

  #   @query_service.class.s3_host
  # end



  def globus_url
    URI(File.join(Rails.configuration.globus['post_curation_base_url'], filename))
  end
end
