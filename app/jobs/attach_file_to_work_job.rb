# frozen_string_literal: true

class AttachFileToWorkJob < ApplicationJob
  queue_as :default

  def perform(file_path:, file_name:, size:, background_upload_snapshot_id:)
    @file_path = file_path
    @file_name = file_name
    @size = size

    @background_upload_snapshot_id = background_upload_snapshot_id

    File.open(file_path) do |file|
      unless work.s3_query_service.upload_file(io: file.to_io, filename: file_name, size: @size)
        raise "An error uploading #{file_name} was encountered for work #{work}"
      end
    end
    File.delete(file_path)

    background_upload_snapshot.with_lock do
      background_upload_snapshot.reload
      background_upload_snapshot.mark_complete(file_name, work.s3_query_service.last_response.etag.delete('"'))
      background_upload_snapshot.save!
    end
  end

  private

    def background_upload_snapshot
      @background_upload_snapshot ||= BackgroundUploadSnapshot.find(@background_upload_snapshot_id)
    end

    def work
      @work ||= background_upload_snapshot.work
    end
end
