# frozen_string_literal: true

class AttachFileToWorkJob < ApplicationJob
  queue_as :default

  def perform(work_id:, user_id:, file_path:, file_name:, size:)
    @work_id = work_id
    @user_id = user_id

    @file_path = file_path
    @file_name = file_name
    @size = size

    File.open(file_path) do |file|
      unless work.s3_query_service.upload_file(io: file.to_io, filename: file_name)
        raise "An error uploading #{file_name} was encountered for work #{work}"
      end
    end

    work.track_change(:added, @file_name)
    work.log_file_changes(@user_id)
  end

  private

    def work
      @work ||= Work.find(@work_id)
    end
end
