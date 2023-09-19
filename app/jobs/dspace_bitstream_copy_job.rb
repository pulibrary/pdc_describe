# frozen_string_literal: true
class DspaceBitstreamCopyJob < ApplicationJob
  queue_as :default

  def perform(dspace_files_json:, work_id:, migration_snapshot_id:)
    dspace_files = JSON.parse(dspace_files_json).map { |json_file| S3File.from_json(json_file) }
    @work = Work.find(work_id)

    dspace_files.each do |dspace_file|
      # Rename files so they are S3 safe
      dspace_file.filename_display = FileRenameService.new(dspace_file.filename_display)
      migrate_file(dspace_file, migration_snapshot_id)
    end
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

    def file_complete?(migratoion_snapshot, dspace_file)
      s3_file = dspace_file.clone
      s3_file.filename = s3_file.filename_display
      migratoion_snapshot.complete?(s3_file)
    end
end
