# frozen_string_literal: true
class S3File
  attr_accessor :filename, :last_modified, :size, :checksum

  def initialize(filename:, last_modified:, size:, checksum:)
    @filename = filename
    @last_modified = last_modified
    @size = size
    @checksum = checksum.delete('"')
  end
end
