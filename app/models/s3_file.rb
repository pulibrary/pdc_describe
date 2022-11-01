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

  def globus_url
    encoded_filename = filename.split("/").map{ |name| CGI.escape(name) }.join("/")
    File.join(Rails.configuration.globus["post_curation_base_url"], encoded_filename)
  end
end
