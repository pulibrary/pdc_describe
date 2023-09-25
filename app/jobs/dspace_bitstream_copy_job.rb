# frozen_string_literal: true
class DspaceBitstreamCopyJob < ApplicationJob
  queue_as :default

  # For each file from DSpace, queue up a migration.
  # If the file contains characters that are not S3 safe, re-name the file.
  # Note that the dspace_file.filename_display will be the file's key in S3.
  # Files that are re-named must be re-named sequentially, and we must provide
  # a list of all of the re-naming that occurred, and include that file in
  # what is uploaded to S3.
  def perform(dspace_files_json:, work_id:, migration_snapshot_id:)
    dspace_files = JSON.parse(dspace_files_json).map { |json_file| S3File.from_json(json_file) }
    @work = Work.find(work_id)
    frms = FileRenameMappingService.new(upload_snapshot: MigrationUploadSnapshot.find(migration_snapshot_id))
    dspace_files.each do |dspace_file|
      if FileRenameService.new(filename: dspace_file.filename_display).needs_rename?
        # Rename files so they are S3 safe
        dspace_file.filename_display = frms.renamed_files[dspace_file.filename_display]
      end
      migrate_file(dspace_file, migration_snapshot_id)
    end
    upload_rename_mapping(frms)
  end

  private

    def migrate_file(dspace_file, migration_snapshot_id)
      # Allow a restart if there is an error with one file
      snapshot = MigrationUploadSnapshot.find(migration_snapshot_id)
      return if file_complete?(snapshot, dspace_file)

      downloaded_file = download_dspace_file(dspace_file, migration_snapshot_id)
      return if downloaded_file.nil?
      aws_connector = PULDspaceAwsConnector.new(@work, @work.doi)
      result = aws_connector.upload_to_s3([dspace_file]).first
      update_migration_status(migration_snapshot_id) do |migration_snapshot|
        if result[:error].present?
          migration_snapshot.mark_error(result[:file], result[:error])
        else
          # update the checksum here
          migration_snapshot.mark_complete(result[:file])
        end
      end
      File.delete(downloaded_file.filename) if File.exist?(downloaded_file.filename)
    end

    def download_dspace_file(dspace_file, migration_snapshot_id)
      dspace_connector = PULDspaceConnector.new(@work)
      downloaded_file = dspace_connector.download_bitstreams([dspace_file]).first
      if downloaded_file.is_a?(Hash)
        update_migration_status(migration_snapshot_id) do |migration_snapshot|
          migration_snapshot.mark_error(downloaded_file[:file], downloaded_file[:error])
        end
        nil
      else
        downloaded_file
      end
    end

    def update_migration_status(migration_snapshot_id)
      migration_snapshot = MigrationUploadSnapshot.find(migration_snapshot_id)
      migration_snapshot.with_lock do
        migration_snapshot.reload
        yield migration_snapshot
        migration_snapshot.save!
      end
    end

    def file_complete?(migration_snapshot, dspace_file)
      s3_file = dspace_file.clone
      s3_file.filename = s3_file.filename_display
      migration_snapshot.complete?(s3_file)
    end

    # If any files were renamed, upload a text file containing
    # the original file names and what they were renamed to.
    def upload_rename_mapping(frms)
      return unless frms.rename_needed?

      filename = "renamed_files.txt"
      io = StringIO.new
      io.write frms.renaming_document
      io.rewind
      size = io.size
      checksum = Digest::MD5.new
      checksum.update(io.read)
      base64 = checksum.base64digest
      io.rewind
      @work.s3_query_service.upload_file(io: io, filename: filename, size: size, md5_digest: base64)
    end
end
