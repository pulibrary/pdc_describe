# frozen_string_literal: true
class WorkUploadsEditService
  attr_reader :work, :s3_service

  def initialize(work, current_user)
    @work = work
    @s3_service = work.s3_query_service
    @current_user = current_user
    @changes = []
  end

  def update_precurated_file_list(added_files, deleted_files)
    delete_uploads(deleted_files)
    add_uploads(added_files)
    if @changes.count > 0
      work.log_file_changes(@changes, @current_user.id)
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
      deleted_files.each do |filename|
        s3_service.delete_s3_object(filename)
        track_change(:deleted, filename)
      end
    end

    def add_uploads(added_files)
      added_files.each do |new_upload|
        work.pre_curation_uploads.attach(new_upload)
        track_change(:added, new_upload.original_filename)
      end
    end

    def track_change(action, filename)
      @changes << { action: action, filename: filename }
    end
end
