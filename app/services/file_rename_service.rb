# frozen_string_literal: true

# We sometimes have data with filenames that contain characters that AWS S3 cannot handle. In those cases we want to:
# 1.  Rename the files to something that is AWS legal. Replace all illegal characters with a _ (underscore)
# 2.  Ensure there are no duplicate file names after the renaming by appending a (1), (2) at the end of the filename
#     if the file has been renamed
# 3.  Keep a record of all of the file names as they originally existed and what they were renamed to
# 4.  The record goes into a file called files_renamed.txt, which contains a list of all files that have been renamed
#     and what they were renamed to, along with a timestamp
# 5.  This files_renamed.txt file gets added to the dataset as a payload file, akin to a README.txt or license.txt
class FileRenameService
  # See this reference for the full list of characters that cannot be used in filenames for AWS S3:
  # https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-keys.html
  # This service will only attempt to fix the most likely problems. For example, we will not try to
  # handle "ASCII character ranges 00–1F hex (0–31 decimal) and 7F (127 decimal)"
  ILLEGAL_CHARACTERS = [
    "&", "$", "@", "=", ";", ":", "+", " ", ",", "?", "\\", "{", "}", "^", "%", "`", "[", "]", "'", '"', ">", "<", "~", "#", "|"
  ].freeze

  attr_reader :original_filename

  def initialize(filename:)
    @original_filename = filename
  end

  def needs_rename?
    @needs_rename ||= check_if_file_needs_rename
  end

  def check_if_file_needs_rename
    ILLEGAL_CHARACTERS.each do |char|
      return true if @original_filename.include? char
    end
    false
  end

  # Replace every instance of an illegal character with an underscore
  def new_filename
    nf = @original_filename.dup
    ILLEGAL_CHARACTERS.each do |char|
      nf.gsub!(char, "_")
    end
    nf
  end
end
