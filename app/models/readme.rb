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
    return nil if ActiveStorage::Blob.service.name == :local
    remove_old_readme

    key = upload_readme(readme_file_param)
    if key
      @file_names = [readme_file_param.original_filename]
      @s3_readme_idx = 0
      log_change(key)
      nil
    else
      "An error uploading your README was encountered.  Please try again."
    end
  end

  def attach_other(file)
    extension = File.extname(file.original_filename)
    filename = file.original_filename # TODO sanitize
    puts "==> attach_other #{filename} started"
    size = file.size
    key = work.s3_query_service.upload_file(io: file.to_io, filename:, size:)
    puts "==> attach_other #{filename} ended"
    if key
      log_change(key)
      nil
    else
      "An error uploading your #{filename}.  Please try again."
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
        @file_names ||= work.pre_curation_uploads_fast.map(&:filename_display)
      end

      def remove_old_readme
        return if blank?
        work.track_change(:removed, work.pre_curation_uploads_fast[s3_readme_idx].key)
        work.s3_query_service.delete_s3_object(work.pre_curation_uploads_fast[s3_readme_idx].key)
      end

      def upload_readme(readme_file_param)
        extension = File.extname(readme_file_param.original_filename)
        readme_name = "README#{extension}"
        size = readme_file_param.size
        work.s3_query_service.upload_file(io: readme_file_param.to_io, filename: readme_name, size:)
      end

      def log_change(key)
        last_response = work.s3_query_service.last_response
        UploadSnapshot.create(work:, files: [{ "filename" => key, "checksum" => last_response.etag.delete('"') }])
        work.track_change(:added, key)
        work.log_file_changes(current_user.id)
      end
end
