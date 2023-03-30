# frozen_string_literal: true
class WorkUploadsEditService
  attr_reader :work, :s3_service

  def initialize(work, current_user)
    @work = work
    @s3_service = work.s3_query_service
    @current_user = current_user
    @changes = []
  end

  def update_precurated_file_list(work_params)
    if work_params.key?(:deleted_uploads) || work_params.key?(:pre_curation_uploads_new) || work_params.key?(:replaced_uploads)
      if work_params.key?(:deleted_uploads)
        delete_pre_curation_uploads(work_params[:deleted_uploads])
      elsif work_params.key?(:pre_curation_uploads_new)
        add_uploads(work_params)
      elsif work_params.key?(:replaced_uploads)
        replace_uploads(work_params[:replaced_uploads])
      end
      work.log_file_changes(@changes, @current_user.id)
      s3_service.client_s3_files(reload: true)
      work.reload # reload the work to pick up the changes in the attachments
    else # no changes in the parameters, just return the original work
      work
    end
  end

  def find_post_curation_uploads(upload_keys: [])
    return [] unless work.approved? && !upload_keys.empty?
    work.post_curation_uploads.select { |upload| upload_keys.include?(upload.key) }
  end

  private

    def replace_uploads(replaced_uploads_params)
      replaced_uploads_params.keys.each do |key|
        s3_service.delete_s3_object(key)
        track_change(:deleted, key)
        new_upload = replaced_uploads_params[key]
        work.pre_curation_uploads.attach(new_upload)
        track_change(:added, new_upload.original_filename)
      end
    end

    def delete_pre_curation_uploads(deleted_uploads_params)
      deleted_uploads_params.each do |delete_s3|
        s3_service.delete_s3_object(delete_s3.first) if delete_s3.last == "1"
        track_change(:deleted, delete_s3.first)
      end
    end

    def add_uploads(work_params)
      Array(work_params[:pre_curation_uploads_new]).each do |new_upload|
        work.pre_curation_uploads.attach(new_upload)
        track_change(:added, new_upload.original_filename)
      end
    end

    def track_change(action, filename)
      @changes << { action: action, filename: filename }
    end
end
