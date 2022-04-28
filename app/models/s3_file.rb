# frozen_string_literal: true
class S3File
  attr_accessor :filename, :last_modified, :size

  def initialize(filename:, last_modified:, size:)
    @filename = filename
    @last_modified = last_modified
    @size = size
  end
end
