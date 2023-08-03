# frozen_string_literal: true
class DspaceBitstreamCopyJob < ApplicationJob
  queue_as :default

  def perform(dspace_files_json:, work_id:, migration_snapshot_id:)
    dspace_files = JSON.parse(dspace_files_json).map { |json_file| S3File.from_json(json_file) }
    @work = Work.find(work_id)

    dspace_files.each do |dspace_file|
      migrate_file(dspace_file, migration_snapshot_id)
    end
  end

  private

    def migrate_file(dspace_file, migration_snapshot_id)
      # Allow a restart if there is an error with one file
      snapshot = MigrationUploadSnapshot.find(migration_snapshot_id)
      return if snapshot.complete?(dspace_file)

      downloaded_file = download_dspace_file(dspace_file, migration_snapshot_id)
      return if downloaded_file.nil?
      aws_connector = PULDspaceAwsConnector.new(@work, @work.doi)
      result = aws_connector.upload_to_s3([dspace_file]).first
      update_migration_status(migration_snapshot_id) do |migration_snapshot|
        if result[:error].present?
          migration_snapshot.mark_error(result[:file], result[:error])
        else
          migration_snapshot.mark_complete(result[:file])
        end
      end
      File.delete(downloaded_file.filename) if File.exist?(downloaded_file.filename)
    end

    def download_dspace_file(dspace_file, migration_snapshot_id)
      dspace_connector = PULDspaceConnector.new(@work)
      downloaded_file = dspace_connector.download_bitstreams([dspace_file]).first
      if downloaded_file.is_a?(Hash)
        update_migration_status(migration_snapshot_id) do |migration_snapshot|
          migration_snapshot.mark_error(downloaded_file[:file], downloaded_file[:error])
        end
        nil
      else
        downloaded_file
      end
    end

    def update_migration_status(migration_snapshot_id)
      migration_snapshot = MigrationUploadSnapshot.find(migration_snapshot_id)
      migration_snapshot.with_lock do
        migration_snapshot.reload
        yield migration_snapshot
        migration_snapshot.save!
      end
    end

    def download_bitstream(retrieval_path, filename)
      url = "#{Rails.configuration.dspace.base_url}#{retrieval_path}"
      path = File.join(Rails.configuration.dspace.download_file_path, "dspace_download", work.id.to_s)
      FileUtils.mkdir_p path
      download_file(url, filename)
      filename
    end

    def download_file(url, filename)
      http = request_http(url)
      uri = URI(url)
      req = Net::HTTP::Get.new uri.path
      http.request req do |response|
        io = File.open(filename, "w")
        response.read_body do |chunk|
          io.write chunk.force_encoding("UTF-8")
        end
        io.close
      end
    end

    def checksum_file(filename, original_checksum)
      checksum = Digest::MD5.file(filename)
      base64 = checksum.base64digest
      if base64 != original_checksum
        msg = "Mismatching checksum #{filename} #{original_checksum} for work: #{work.id} doi: #{work.doi} ark: #{work.ark}"
        Rails.logger.error msg
        Honeybadger.notify(msg)
        false
      else
        Rails.logger.debug "Matching checksums for #{filename}"
        true
      end
    end

    def request_http(url)
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http
    end
end
