# frozen_string_literal: true

class AttachFileToWorkJob < ApplicationJob
  queue_as :default

  def perform(work_id:, user_id:, file_path:, file_name:, size:)
    @work_id = work_id
    @user_id = user_id

    @file_path = file_path
    @file_name = file_name
    @size = size

    blob = create_blob

    work.pre_curation_uploads.attach(blob)
    work.track_change(:added, @file_name)
    work.log_file_changes(@user_id)
  end

  private

    def work
      @work ||= Work.find(@work_id)
    end

    def create_blob
      params = { filename: @file_name, content_type: "", byte_size: @size, checksum: "" }

      blob = ActiveStorage::Blob.create_before_direct_upload!(**params)
      blob.key = @file_name
      blob
    end
end
