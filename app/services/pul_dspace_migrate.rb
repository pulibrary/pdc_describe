# frozen_string_literal: true
class PULDspaceMigrate
  attr_reader :work, :ark, :file_keys, :directory_keys, :dpsace_connector, :aws_connector, :migration_snapshot

  delegate :doi, to: :dpsace_connector

  def initialize(work)
    @work = work
    @ark = work.ark&.gsub("ark:/", "")
    @file_keys = []
    @directory_keys = []
    @dpsace_connector = PULDspaceConnector.new(work)
    @aws_connector = PULDspaceAwsConnector.new(work, doi)
    @migration_snapshot = nil
  end

  def migrate
    return if ark.nil?
    work.resource.migrated = true
    work.save
    aws_files = aws_connector.aws_files
    dspace_files = dpsace_connector.download_bitstreams
    generate_migration_snapshot(dspace_files, aws_files)
    migrate_dspace(dspace_files)
    aws_copy(aws_files)
  end

  def migration_message
    "Migration for #{file_keys.count} #{'file'.pluralize(file_keys.count)} and #{directory_keys.count} #{'directory'.pluralize(directory_keys.count)}"
  end

  private

    def generate_migration_snapshot(dspace_files, aws_files)
      files = new_dspace_files(dspace_files) + new_aws_files(aws_files)
      snapshot = MigrationUploadSnapshot.new(work: work, url: work.s3_query_service.prefix)
      last_snapshot = work.upload_snapshots.first
      snapshot.store_files(files, pre_existing_files: last_snapshot&.files)
      snapshot.save!
      @migration_snapshot = snapshot
    end

    def new_dspace_files(dspace_files)
      dspace_files.map do |s3_file|
        new_s3 = s3_file.clone
        new_s3.filename = work.s3_query_service.prefix + File.basename(s3_file.filename)
        new_s3
      end
    end

    def new_aws_files(aws_files)
      aws_files.reject(&:directory?).map do |s3_file|
        new_s3 = s3_file.clone
        new_s3.filename = s3_file.filename.gsub("#{doi}/".tr(".", "-"), work.s3_query_service.prefix)
        new_s3
      end
    end

    def migrate_dspace(dspace_files)
      if dspace_files.any?(nil)
        bitstreams = dpsace_connector.bitstreams
        error_files = Hash[dspace_files.zip bitstreams].select { |key, _value| key.nil? }
        error_names = error_files.map { |bitstream| bitstream["name"] }.join(", ")
        raise "Error downloading file(s) #{error_names}"
      end
      errors = upload_dspace_files(dspace_files)
      if errors.count > 0
        raise "Error uploading file(s):\n #{errors.join("\n")}" if errors.count > 0
      end

      dspace_files.each { |file| File.delete(file.filename) }
    end

    def upload_dspace_files(dspace_files)
      results = aws_connector.upload_to_s3(dspace_files)
      error_results = results.select { |result| result[:error].present? }
      good_results = results.select { |result| result[:key].present? }
      good_results.each do |result|
        @migration_snapshot&.mark_complete(result[:file])
        file_keys << result[:key]
      end
      @migration_snapshot&.save
      error_results.map { |result| result[:error] }
    end

    def aws_copy(files)
      files.each do |s3_file|
        DspaceFileCopyJob.perform_later(doi, s3_file.key, s3_file.size, work.id, @migration_snapshot&.id)
        if s3_file.directory?
          directory_keys << s3_file.key
        else
          file_keys << s3_file.key
        end
      end
    end

    def request_http(url)
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http
    end
end
