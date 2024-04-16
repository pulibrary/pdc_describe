# frozen_string_literal: true
class WorkUploadsEditService
  attr_reader :work, :s3_service, :current_user

  def initialize(work, current_user)
    @work = work
    @s3_service = work.s3_query_service
    @current_user = current_user
  end

  def update_precurated_file_list(added_files, deleted_files)
    delete_uploads(deleted_files)
    add_uploads(added_files)
    if work.changes.count > 0
      s3_service.client_s3_files(reload: true)
      work.reload # reload the work to pick up the changes in the attachments
    end

    work
  end

  # Delete any files the user has decided not to keep and
  #  add all files that were uploaded in the backgroud via uppy and any files deleted to an upload snapshot
  #
  # @param [Array] deleted_files files that exist in AWS that should be removed
  def snapshot_uppy_and_delete_files(deleted_files)
    deleted_files.each do |filename|
      s3_service.delete_s3_object(filename)
    end

    # assigns all backgroun changes and deletes to the current user
    work.reload_snapshots(user_id: current_user.id)
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
        work.track_change(:removed, filename)
      end
      work.log_file_changes(@current_user.id)
    end

    def add_uploads(added_files)
      return if added_files.empty?

      last_snapshot = work.upload_snapshots.first
      snapshot = BackgroundUploadSnapshot.new(work:)
      snapshot.store_files(added_files, pre_existing_files: last_snapshot&.files, current_user: @current_user)
      snapshot.save
      added_files.map do |file|
        new_path = "/tmp/#{file.original_filename}"
        FileUtils.mv(file.path, new_path)
        AttachFileToWorkJob.perform_later(file_path: new_path, file_name: file.original_filename, size: file.size, background_upload_snapshot_id: snapshot.id)
      end
    end
end
