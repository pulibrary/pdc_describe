# frozen_string_literal: true
class MigrationUploadSnapshot < UploadSnapshot
  def store_files(s3_files, pre_existing_files: [])
    self.files = s3_files.map { |file| { "filename" => file.filename_display, "checksum" => file.checksum, "migrate_status" => "started" } }
    files.concat pre_existing_files if pre_existing_files.present?
  end

  def mark_error(s3_file, error_message)
    index = find_file(s3_file.filename_display)
    if index.present?
      files[index]["migrate_status"] = "error"
      files[index]["migrate_error"] = error_message
    end
  end

  def mark_complete(s3_file)
    index = find_file(s3_file.filename)
    if index.present?
      files[index]["migrate_status"] = "complete"
      finalize_migration if migration_complete?
    end
  end

  def migration_complete?
    files.select { |file| file.keys.include?("migrate_status") }.map { |file| file["migrate_status"] }.uniq == ["complete"]
  end

  def migration_complete_with_errors?
    return false if migration_complete?
    !files.select { |file| file.keys.include?("migrate_status") }.map { |file| file["migrate_status"] }.uniq.include?("started")
  end

  def existing_files
    super.select { |file| file["migrate_status"].nil? || file["migrate_status"] == "complete" }
  end

  def finalize_migration
    migration_start = WorkActivity.activities_for_work(work.id, [WorkActivity::MIGRATION_START]).order(created_at: :desc)
    if migration_start.count == 0
      Honeybadger.notify("Finalized a migration with no start! Work: #{work.id} Migration Snapshot: #{id}")
      WorkActivity.add_work_activity(work.id, { migration_id: id, message: "Migration from Dataspace is complete." }.to_json,
                                     nil, activity_type: WorkActivity::MIGRATION_COMPLETE)
    else
      migration = migration_start.first
      data = JSON.parse(migration.message)
      message = "#{data['file_count']} #{'file'.pluralize(data['file_count'])} and #{data['directory_count']} #{'directory'.pluralize(data['directory_count'])} have migrated from Dataspace."
      WorkActivity.add_work_activity(work.id, { migration_id: id, message: message }.to_json,
                                                migration.created_by_user_id, activity_type: WorkActivity::MIGRATION_COMPLETE)
    end
  end

  private

    def find_file(filename)
      index = files.index { |file| file["filename"] == filename && file["migrate_status"] == "started" }
      if index.nil?
        Honeybadger.notify("Migrated a file that was not part of the orginal Migration: #{id} for work #{work_id}: #{filename}")
      end
      index
    end
end
