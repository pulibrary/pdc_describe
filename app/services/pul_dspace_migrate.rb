# frozen_string_literal: true
class PULDspaceMigrate
  attr_reader :work, :ark, :file_keys, :directory_keys, :current_user,
              :aws_connector, :migration_snapshot, :dspace_files, :aws_files_and_directories

  delegate :doi, to: :dspace_connector

  def initialize(work, current_user)
    @work = work
    @ark = work.ark&.gsub("ark:/", "")
    @file_keys = []
    @directory_keys = []
    @aws_connector = PULDspaceAwsConnector.new(work, work.doi)
    @migration_snapshot = nil
    @aws_files_and_directories = nil
    @dspace_files = []
    @current_user = current_user
  end

  def migrate
    return if ark.nil?
    work.resource.migrated = true
    work.save
    @aws_files_and_directories = aws_connector.aws_files
    migrate_dspace

    aws_copy(aws_files_and_directories)
  end

  def dspace_connector
    @dspace_connector ||= PULDspaceConnector.new(work)
  end

  def migration_message(input_file_keys = file_keys, input_directory_keys = directory_keys)
    message = []
    # rubocop:disable Layout/LineLength
    message << "Migration for #{input_file_keys.count} #{'file'.pluralize(input_file_keys.count)} and #{input_directory_keys.count} #{'directory'.pluralize(input_directory_keys.count)} is running in the background. Depending on the file sizes this may take some time."
    # rubocop:enable Layout/LineLength
    message.join(" ")
  end

  private

    def generate_migration_snapshot
      files = remove_overlap_and_combine
      snapshot = MigrationUploadSnapshot.new(work:, url: work.s3_query_service.prefix)
      last_snapshot = work.upload_snapshots.first
      snapshot.store_files(files, pre_existing_files: last_snapshot&.files)
      snapshot.save!
      directories = aws_files_and_directories.select(&:directory?)
      WorkActivity.add_work_activity(work.id, { migration_id: snapshot.id,
                                                message: migration_message(files, directories), file_count: files.count,
                                                directory_count: directories.count }.to_json,
                                      current_user.id, activity_type: WorkActivity::MIGRATION_START)
      @migration_snapshot = snapshot
    end

    def remove_overlap_and_combine
      dpsace_update_display_to_final_key
      aws_update_display_to_final_key(aws_files_and_directories)
      aws_files_only = aws_files_and_directories.reject(&:directory?)
      aws_file_names = aws_files_only.map(&:filename_display)
      files_to_remove = []
      dspace_files.each do |s3_file|
        idx = aws_file_names.index(s3_file.filename_display)
        if idx.present?
          check_matching_files(aws_files_only[idx], s3_file, files_to_remove)
        end
      end
      @dspace_files = dspace_files - files_to_remove
      @dspace_files.each { |file| file_keys << file.filename_display }
      dspace_files + aws_files_only
    end

    def dpsace_update_display_to_final_key
      dspace_files.each do |s3_file|
        s3_file.filename_display = work.s3_query_service.prefix + s3_file.filename_display
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

    def migrate_dspace
      @dspace_files = dspace_connector.list_bitsteams
      generate_migration_snapshot
      dspace_files_json = "[#{dspace_files.map(&:to_json).join(',')}]"
      DspaceBitstreamCopyJob.perform_later(dspace_files_json:, work_id: work.id, migration_snapshot_id: migration_snapshot.id)
    end

    def aws_copy(files)
      Honeybadger.notify("DspaceFileCopyJob started for ark #{work.ark} doi #{work.doi} without a migration snapshot") unless @migration_snapshot
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
