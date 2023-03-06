# frozen_string_literal: true
class UploadSnapshot < ApplicationRecord
  belongs_to :work
  attr_writer :upload

  def upload
    @upload ||= uploads.find { |s3_file| uri.include?(s3_file.url) }
  end

  private

    def uploads
      work.uploads
    end
end
