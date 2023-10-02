# frozen_string_literal: true
class UploadSnapshot < ApplicationRecord
  belongs_to :work
  attr_writer :upload

  alias_attribute :existing_files, :files

  def snapshot_deletions(work_changes, s3_filenames)
    existing_files.each do |file|
      filename = file["filename"]
      unless s3_filenames.include?(filename)
        work_changes << { action: "removed", filename:, checksum: file["checksum"] }
      end
    end
  end

  def snapshot_modifications(work_changes, s3_files)
    # check for modifications
    s3_files.each do |s3_file|
      next if match?(s3_file)
      work_changes << if include?(s3_file)
                        { action: "replaced", filename: s3_file.filename, checksum: s3_file.checksum }
                      else
                        { action: "added", filename: s3_file.filename, checksum: s3_file.checksum }
                      end
    end
  end

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
    files.index { |file| file["filename"] == s3_file.filename && checksum_compare(file["checksum"], s3_file.checksum) }
  end

  def match?(s3_file)
    index(s3_file).present?
  end

  def store_files(s3_files)
    self.files = s3_files.map { |file| { "filename" => file.filename, "checksum" => file.checksum } }
  end

  def self.find_by_filename(work_id:, filename:)
    find_by("work_id = ? AND files @> ?", work_id, JSON.dump([{ filename: }]))
  end

  private

    def uploads
      work.uploads
    end

    # Compares two checksums. Accounts for the case in which one of them is
    # a plain MD5 value and the other has been encoded with base64.
    # See also
    #   https://ruby-doc.org/core-2.7.0/Array.html#method-i-pack
    #   https://ruby-doc.org/core-2.7.0/String.html#method-i-unpack
    def checksum_compare(checksum1, checksum2)
      if checksum1 == checksum2
        true
      elsif checksum1.nil? || checksum2.nil?
        false
      elsif checksum1.length < checksum2.length
        # Decode the first one and then compare
        checksum1.unpack("m0").first.unpack("H*").first == checksum2
      else
        # Decode the second one and then compare
        checksum1 == checksum2.unpack("m0").first.unpack("H*").first
      end
    rescue ArgumentError
      # One of the values was not properly encoded
      false
    end
end
