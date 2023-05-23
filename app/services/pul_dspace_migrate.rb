# frozen_string_literal: true
class PULDspaceMigrate
  attr_reader :work, :ark, :file_keys, :directory_keys, :dpsace_connector,
              :aws_connector, :migration_snapshot, :dspace_files, :aws_files_and_directories

  delegate :doi, to: :dpsace_connector

  def initialize(work)
    @work = work
    @ark = work.ark&.gsub("ark:/", "")
    @file_keys = []
    @directory_keys = []
    @dpsace_connector = PULDspaceConnector.new(work)
    @aws_connector = PULDspaceAwsConnector.new(work, doi)
    @migration_snapshot = nil
    @aws_files_and_directories = nil
    @dspace_files = nil
  end

  def migrate
    return if ark.nil?
    work.resource.migrated = true
    work.save
    @aws_files_and_directories = aws_connector.aws_files
    @dspace_files = dpsace_connector.download_bitstreams
    generate_migration_snapshot
    migrate_dspace(dspace_files)
    aws_copy(aws_files_and_directories)
  end

  def migration_message
    "Migration for #{file_keys.count} #{'file'.pluralize(file_keys.count)} and #{directory_keys.count} #{'directory'.pluralize(directory_keys.count)}"
  end

  private

    def generate_migration_snapshot
      files = remove_overlap_and_combine
      snapshot = MigrationUploadSnapshot.new(work: work, url: work.s3_query_service.prefix)
      last_snapshot = work.upload_snapshots.first
      snapshot.store_files(files, pre_existing_files: last_snapshot&.files)
      snapshot.save!
      @migration_snapshot = snapshot
    end

    def remove_overlap_and_combine
      dpsace_update_display_to_final_key
      aws_files_only = aws_files_and_directories.reject(&:directory?)
      aws_update_display_to_final_key(aws_files_only)
      aws_file_names = aws_files_only.map(&:filename_display)
      files_to_remove = []
      dspace_files.each do |s3_file|
        idx = aws_file_names.index(s3_file.filename_display)
        if idx.present?
          check_matching_files(aws_files_only[idx], s3_file, files_to_remove)
        end
      end
      @dspace_files = dspace_files - files_to_remove
      dspace_files + aws_files_only
    end

    def dpsace_update_display_to_final_key
      dspace_files.each do |s3_file|
        s3_file.filename_display = work.s3_query_service.prefix + File.basename(s3_file.filename)
      end
    end

    def aws_update_display_to_final_key(aws_files)
      aws_files.each do |s3_file|
        s3_file.filename_display = s3_file.filename.gsub("#{doi}/".tr(".", "-"), work.s3_query_service.prefix)
      end
    end

    def check_matching_files(aws_file, dpace_file, files_to_remove)
      if dpace_file.checksum == aws_file.checksum
        files_to_remove << dpace_file
      else
        basename = File.basename(dpace_file.filename_display)
        dpace_file.filename_display.gsub!(basename, "data_space_#{basename}")
        aws_file.filename_display.gsub!(basename, "globus_#{basename}")
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
        DspaceFileCopyJob.perform_later(s3_file_json: s3_file.to_json, work_id: work.id, migration_snapshot_id: @migration_snapshot&.id)
        if s3_file.directory?
          directory_keys << s3_file.key
        else
          file_keys << s3_file.filename_display
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
