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

  delegate :bucket_name, to: :@query_service

  def uri
    URI("#{@query_service.class.url_protocol}://#{bucket_name}.#{@query_service.class.s3_host}/#{filename}")
  end

  def url
    uri.to_s
  end
end
