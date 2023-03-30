# frozen_string_literal: true
class Readme
  attr_reader :work

  def initialize(work)
    @work = work
  end

  def attach(readme_file_param)
    return "A README file is required!" if readme_file_param.blank? && blank?
    return nil if readme_file_param.blank?

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

    private

      def s3_readme_idx
        file_names = work.pre_curation_uploads_fast.map(&:filename_display)
        file_names.find_index { |file_name| file_name.start_with?("README") }
      end
end
