# frozen_string_literal: true
class PULDspaceAwsConnector
  attr_reader :work, :ark, :dspace_doi, :migration_snapshot

  def initialize(work, dspace_doi)
    @work = work
    @ark = work.ark&.gsub("ark:/", "")
    @dspace_doi = dspace_doi
  end

  def upload_to_s3(dspace_files)
    dspace_files.map do |dspace_file|
      filename = dspace_file.filename
      match_dspace_file = dspace_file.clone
      basename = File.basename(dspace_file.filename_display)
      match_dspace_file.filename = dspace_file.filename_display
      io = File.open(filename)
      size = File.size(filename)
      key = work.s3_query_service.upload_file(io:, filename: basename, md5_digest: dspace_file.checksum, size:)
      if key
        { key:, file: match_dspace_file, error: nil }
      else
        { key: nil, file: match_dspace_file, error: "An error uploading #{filename}.  Please try again." }
      end
    end
  end

  def aws_files
    return [] if ark.nil? || dspace_doi.nil?
    @aws_files ||= work.s3_query_service.client_s3_files(reload: true, bucket_name: dspace_bucket_name, prefix: dspace_doi.tr(".", "-"), ignore_directories: false)
  end

  private

    def dspace_bucket_name
      @dspace_bucket_name ||= Rails.configuration.s3.dspace[:bucket]
    end
end
