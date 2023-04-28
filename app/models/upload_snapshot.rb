# frozen_string_literal: true
class UploadSnapshot < ApplicationRecord
  belongs_to :work
  attr_writer :upload

  before_create do
    persisted = UploadSnapshot.where(filename: filename, url: url, work: work)

    next_version = if persisted.empty?
                     1
                   else
                     persisted.last.version + 1
                   end
    self.version = next_version
  end

  def upload
    @upload ||= uploads.find { |s3_file| s3_file.filename == filename }
  end

  def uri
    URI.parse(url)
  end

  def key
    "#{filename}-#{version}"
  end

  private

    def uploads
      work.uploads
    end
end
