# frozen_string_literal: true
class WorkUploadsEditService
  attr_reader :work

  def initialize(work, current_user)
    @work = work
    @current_user = current_user
    @changes = []
  end

  def update_precurated_file_list(work_params)
    if work_params.key?(:deleted_uploads) || work_params.key?(:pre_curation_uploads) || work_params.key?(:replaced_uploads)
      if work_params.key?(:deleted_uploads)
        delete_pre_curation_uploads(work_params[:deleted_uploads])
      elsif work_params.key?(:pre_curation_uploads)
        update_uploads(work_params)
      elsif work_params.key?(:replaced_uploads)
        replace_uploads(work_params[:replaced_uploads])
      end
      work.log_file_changes(@changes, @current_user.id)
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
      new_uploads = []
      work.pre_curation_uploads.each_with_index do |existing, i|
        key = i.to_s
        next unless replaced_uploads_params.key?(key)
        new_uploads << replaced_uploads_params[key]
        track_change(:deleted, existing.filename.to_s)
        existing.purge
      end
      work.reload
      new_uploads.each do |new_upload|
        track_change(:added, new_upload.original_filename)
        work.pre_curation_uploads.attach(new_upload)
      end
    end

    def delete_pre_curation_uploads(deleted_uploads_params)
      work.pre_curation_uploads.each do |existing|
        if deleted_uploads_params.key?(existing.key) && deleted_uploads_params[existing.key] == "1"
          track_change(:deleted, existing.filename.to_s)
          existing.purge
        end
      end
    end

    def update_uploads(work_params)
      # delete all existing uploads...
      work.pre_curation_uploads.each do |existing_upload|
        track_change(:deleted, existing_upload.filename.to_s)
        existing_upload.purge
      end

      # ...reload the work to pick up the changes in the attachments
      work.reload

      # ...and then and then add the ones indicated in the parameters
      Array(work_params[:pre_curation_uploads]).each do |new_upload|
        track_change(:added, new_upload.original_filename)
        work.pre_curation_uploads.attach(new_upload)
      end
    end

    def track_change(action, filename)
      @changes << { action: action, filename: filename }
    end
end
