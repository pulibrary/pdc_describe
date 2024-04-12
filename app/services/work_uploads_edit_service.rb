# frozen_string_literal: true
class WorkUploadsEditService
  attr_reader :work, :s3_service

  def initialize(work, current_user)
    @work = work
    @s3_service = work.s3_query_service
    @current_user = current_user
  end

  def update_precurated_file_list(added_files, deleted_files, fast = false)
    delete_uploads(deleted_files)
    add_uploads(added_files, fast)
    if work.changes.count > 0
      s3_service.client_s3_files(reload: true)
      work.reload # reload the work to pick up the changes in the attachments
    end

    work
  end

  def find_post_curation_uploads(upload_keys: [])
    return [] unless work.approved? && !upload_keys.empty?
    work.post_curation_uploads.select { |upload| upload_keys.include?(upload.key) }
  end

  private

    def delete_uploads(deleted_files)
      return if deleted_files.empty?

      deleted_files.each do |filename|
        s3_service.delete_s3_object(filename)
        work.track_change(:deleted, filename)
      end
      work.log_file_changes(@current_user.id)
    end

    def add_uploads(added_files, fast = false)
      return if added_files.empty?

      last_snapshot = work.upload_snapshots.first
      snapshot = BackgroundUploadSnapshot.new(work:)
      snapshot.store_files(added_files, pre_existing_files: last_snapshot&.files, current_user: @current_user)
      snapshot.save
      added_files.map do |file|
        new_path = "/tmp/#{file.original_filename}"
        FileUtils.mv(file.path, new_path)
        if fast
          AttachFileToWorkJob.perform_now(file_path: new_path, file_name: file.original_filename, size: file.size, background_upload_snapshot_id: snapshot.id)
        else
          AttachFileToWorkJob.perform_later(file_path: new_path, file_name: file.original_filename, size: file.size, background_upload_snapshot_id: snapshot.id)
        end
      end
    end
end
