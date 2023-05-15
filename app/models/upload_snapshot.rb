# frozen_string_literal: true
class UploadSnapshot < ApplicationRecord
  belongs_to :work
  attr_writer :upload

  alias_attribute :existing_files, :files

  def upload
    @upload ||= uploads.find { |s3_file| filenames.include?(s3_file.filename) }
  end

  def uri
    URI.parse(url)
  end

  def filenames
    files.map { |file| file["filename"] }
  end

  def include?(s3_file)
    filenames.include?(s3_file.filename)
  end

  def index(s3_file)
    files.index { |file| file["filename"] == s3_file.filename && file["checksum"] == s3_file.checksum }
  end

  def match?(s3_file)
    index(s3_file).present?
  end

  def store_files(s3_files)
    self.files = s3_files.map { |file| { "filename" => file.filename, "checksum" => file.checksum } }
  end

  def self.find_by_filename(work_id:, filename:)
    find_by("work_id = ? AND files @> ?", work_id, JSON.dump([{ filename: filename }]))
  end

  private

    def uploads
      work.uploads
    end
end
