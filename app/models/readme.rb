# frozen_string_literal: true
class Readme
  attr_reader :work, :current_user

  def initialize(work, current_user)
    @work = work
    @current_user = current_user
  end

  def attach(readme_file_param)
    if readme_file_param.blank?
      message = if blank?
                  "A README file is required!"
                end

      return message
    end

    remove_old_readme

    key = upload_readme(readme_file_param)
    return "An error uploading your README was encountered.  Please try again." unless key

    @file_names = [readme_file_param.original_filename]
    @s3_readme_idx = 0
    log_changes
  end

  def present?
    work.pre_curation_uploads.present? && readme_files_uploaded?
  end

  def blank?
    !present?
  end

  def file_name
    return if blank?

    file_names[s3_readme_idx]
  end

    private

      def s3_readme_idx
        @s3_readme_idx ||= file_names.find_index { |file_name| file_name.upcase.include?("README") }
      end

      def file_names
        @file_names ||= work.pre_curation_uploads.map(&:filename_display)
      end

      def readme_file_names
        @readme_file_names ||= file_names.select { |file_name| file_name.upcase.include?("README") }
      end

      # This determines if any S3 objects contain the substring "readme"
      def readme_files_uploaded?
        readme_file_names.present?
      end

      def remove_old_readme
        return if blank?

        s3_object = work.pre_curation_uploads[s3_readme_idx]
        key = s3_object.key
        work.s3_query_service.delete_s3_object(key)
      end

      def upload_readme(readme_file_param)
        readme_name = readme_file_param.original_filename
        size = readme_file_param.size
        work.s3_query_service.upload_file(io: readme_file_param.to_io, filename: readme_name, size:)
      end

      def log_changes
        work.s3_query_service.client_s3_files(reload: true)
        work.reload_snapshots(user_id: current_user.id)
        nil
      end
end
