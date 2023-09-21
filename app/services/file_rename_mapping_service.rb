# frozen_string_literal: true

# We sometimes have data with filenames that contain characters that AWS S3 cannot handle. In those cases we want to:
# 1.  Rename the files to something that is AWS legal. Replace all illegal characters with a _ (underscore)
# 2.  Ensure there are no duplicate file names after the renaming by appending a (1), (2) at the end of the filename
#     if the file has been renamed
# 3.  Keep a record of all of the file names as they originally existed and what they were renamed to
# 4.  The record goes into a file called files_renamed.txt, which contains a list of all files that have been renamed
#     and what they were renamed to, along with a timestamp
# 5.  This files_renamed.txt file gets added to the dataset as a payload file, akin to a README.txt or license.txt
class FileRenameMappingService
  attr_reader :upload_snapshot, :files, :renamed_files

  def initialize(upload_snapshot:)
    @upload_snapshot = upload_snapshot
    @files = parse_files_to_rename
    @renamed_files = rename_files
  end

  def original_filenames
    @upload_snapshot.files.map { |a| a["filename"] }
  end

  def parse_files_to_rename
    files = []
    original_filenames.each do |original_filename|
      files << FileRenameService.new(filename: original_filename)
    end
    files
  end

  # Make a hash containing all files that need renaming.
  # The key of the hash is the original filename.
  # The value of the hash is the re-named file with an index number appended.
  def rename_files
    rename_index = 1
    renamed_files = {}
    @files.each do |file|
      next unless file.needs_rename?
      renamed_files[file.original_filename] = file.new_filename(rename_index)
      rename_index += 1
    end
    renamed_files
  end

  # A rename is needed if any of the original filenames need renaming
  def rename_needed?
    @files.each do |file|
      return true if file.needs_rename?
    end
    false
  end

  # Format: "Sep 19 2023"
  def rename_date
    Time.zone.now.strftime("%d %b %Y")
  end

  def renaming_document
    message = "Some files have been renamed to comply with AWS S3 storage requirements\n"
    message += "Rename date: #{rename_date}\n"
    message += "Original Filename\t Renamed File\n"
    @files.each do |file|
      next unless file.needs_rename?
      message += "#{file.original_filename}\t#{@renamed_files[file.original_filename]}\n"
    end
    message
  end
end
