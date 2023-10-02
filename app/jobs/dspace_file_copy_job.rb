# frozen_string_literal: true
class DspaceFileCopyJob < ApplicationJob
  queue_as :default

  def perform(s3_file_json:, work_id:, migration_snapshot_id:)
    s3_file = JSON.parse(s3_file_json)
    work = Work.find(work_id)
    new_key = s3_file["filename_display"]
    s3_key = s3_file["filename"]
    s3_size = s3_file["size"]
    resp = work.s3_query_service.copy_file(source_key: "#{dspace_bucket_name}/#{s3_key}",
                                           target_bucket: work.s3_query_service.bucket_name,
                                           target_key: new_key, size: s3_size)
    unless resp.successful?
      raise "Error copying #{s3_key} to work #{work_id} Response #{resp}"
    end
    if s3_size > 0 # All directories are not part of the migration snapshot
      update_migration(migration_snapshot_id, new_key, s3_size, work)
    end
  end

  private

    def dspace_bucket_name
      @dspace_bucket_name ||= Rails.configuration.s3.dspace[:bucket]
    end

    def update_migration(migration_snapshot_id, s3_key, s3_size, work)
      migration_snapshot = MigrationUploadSnapshot.find(migration_snapshot_id)
      migration_snapshot.with_lock do
        migration_snapshot.reload
        migration_snapshot.mark_complete(S3File.new(filename: s3_key, last_modified: DateTime.now, size: s3_size, checksum: "", work:))
        migration_snapshot.save!
      end
    end
end
