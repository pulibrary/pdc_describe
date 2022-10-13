# frozen_string_literal: true
class WorkUploadsEditService
  class << self
    def update_precurated_file_list(work, work_params)
      if work_params.key?(:deleted_uploads) || work_params.key?(:pre_curation_uploads) || work_params.key?(:replaced_uploads)
        if work_params.key?(:deleted_uploads)
          delete_pre_curation_uploads(work.pre_curation_uploads, work_params[:deleted_uploads])
        elsif work_params.key?(:pre_curation_uploads)
          work.pre_curation_uploads.each(&:purge)
          work.reload # reload the work to pick up the changes in the attachments
          Array(work_params[:pre_curation_uploads]).each { |new_upload| work.pre_curation_uploads.attach(new_upload) }
        elsif work_params.key?(:replaced_uploads)
          replace_uploads(work, work_params[:replaced_uploads])
        end
        work.reload # reload the work to pick up the changes in the attachments

      else # no changes in the parameters, just return the original work
        work
      end
    end

    def find_post_curation_uploads(work:, upload_keys: [])
      return [] unless work.approved? && !upload_keys.empty?

      work.post_curation_uploads.select { |upload| upload_keys.include?(upload.key) }
    end

      private

        def replace_uploads(work, replaced_uploads_params)
          new_uploads = []
          work.pre_curation_uploads.each_with_index do |existing, i|
            key = i.to_s
            next unless replaced_uploads_params.key?(key)
            new_uploads << replaced_uploads_params[key]
            existing.purge
          end
          work.reload
          new_uploads.each { |new_upload| work.pre_curation_uploads.attach(new_upload) }
        end

        def delete_pre_curation_uploads(persisted_pre_curation_uploads, deleted_uploads_params)
          persisted_pre_curation_uploads.each do |existing|
            if deleted_uploads_params.key?(existing.key) && deleted_uploads_params[existing.key] == "1"
              existing.purge
            end
          end
        end
  end
end
