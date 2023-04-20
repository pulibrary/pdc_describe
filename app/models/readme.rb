# frozen_string_literal: true
class Readme
  attr_reader :work

  def initialize(work)
    @work = work
  end

  def attach(readme_file_param)
    return "A README file is required!" if readme_file_param.blank? && blank?
    return nil if readme_file_param.blank?
    return nil if ActiveStorage::Blob.service.name == :local
    remove_old_readme

    extension = File.extname(readme_file_param.original_filename)
    if work.s3_query_service.upload_file(io: readme_file_param.to_io, filename: "README#{extension}")
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
        @file_names ||= work.pre_curation_uploads_fast.map(&:filename_display)
      end

      def remove_old_readme
        return if blank?

        work.s3_query_service.delete_s3_object(work.pre_curation_uploads_fast[s3_readme_idx].key)
      end
end
