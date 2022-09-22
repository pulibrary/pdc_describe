# frozen_string_literal: true
class WorkUploadsEditService
  class << self
    def precurated_file_list(work, work_params)
      if work_params.key?(:pre_curation_uploads)
        work_params[:pre_curation_uploads]
      elsif work_params.key?(:replaced_uploads)
        replace_uploads(work.pre_curation_uploads, work_params[:replaced_uploads])
      elsif work_params.key?(:deleted_uploads)
        remaining_pre_curation_uploads(work.pre_curation_uploads, work_params[:deleted_uploads])
      else
        work.pre_curation_uploads.map(&:blob)
      end
    end

    def find_post_curation_uploads(work:, upload_keys: [])
      return [] unless work.approved? && !upload_keys.empty?

      work.post_curation_uploads.select { |upload| upload_keys.include?(upload.key) }
    end

      private

        def replace_uploads(persisted_pre_curation_uploads, replaced_uploads_params)
          updated_uploads = []
          persisted_pre_curation_uploads.each_with_index do |existing, i|
            key = i.to_s

            if replaced_uploads_params.key?(key)
              replaced = replaced_uploads_params[key]
              updated_uploads << replaced
            else
              updated_uploads << existing.blob
            end
          end

          updated_uploads
        end

        def remaining_pre_curation_uploads(persisted_pre_curation_uploads, deleted_uploads_params)
          updated_uploads = []

          persisted_pre_curation_uploads.each do |existing|
            next if deleted_uploads_params.key?(existing.key) && deleted_uploads_params[existing.key] == "1"

            updated_uploads << existing.blob
          end

          updated_uploads
        end
  end
end
