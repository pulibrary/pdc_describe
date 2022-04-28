# frozen_string_literal: true
class S3File
  attr_accessor :filename

  def initialize(filename:)
    @filename = filename
  end
end
