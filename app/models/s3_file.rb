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
    uri.to_s
  end

  private

    def uri
      URI(File.join(Rails.configuration.globus["post_curation_base_url"], filename))
    end
end
