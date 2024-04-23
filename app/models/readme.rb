# frozen_string_literal: true
class Readme
  attr_reader :work, :current_user

  def initialize(work, current_user)
    @work = work
    @current_user = current_user
  end

  def attach(readme_file_param)
    return "A README file is required!" if readme_file_param.blank? && blank?
    return nil if readme_file_param.blank?
    remove_old_readme

    key = upload_readme(readme_file_param)
    if key
      @file_names = [readme_file_param.original_filename]
      @s3_readme_idx = 0
      log_changes
      nil
    else
      "An error uploading your README was encountered.  Please try again."
    end
  end

  def blank?
    s3_readme_idx.nil?
  end

  def file_name
    return nil if blank?
    file_names[s3_readme_idx]
  end

    private

      def s3_readme_idx
        @s3_readme_idx ||= file_names.find_index { |file_name| file_name.start_with?("README") }
      end

      def file_names
        @file_names ||= work.pre_curation_uploads.map(&:filename_display)
      end

      def remove_old_readme
        return if blank?
        work.s3_query_service.delete_s3_object(work.pre_curation_uploads[s3_readme_idx].key)
      end

      def upload_readme(readme_file_param)
        extension = File.extname(readme_file_param.original_filename)
        readme_name = "README#{extension}"
        size = readme_file_param.size
        work.s3_query_service.upload_file(io: readme_file_param.to_io, filename: readme_name, size:)
      end

      def log_changes
        work.s3_query_service.client_s3_files(reload: true)
        work.reload_snapshots(user_id: current_user.id)
      end
end
