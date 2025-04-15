# frozen_string_literal: true
class ApprovedFileMoveJob < ApplicationJob
  queue_as :default
  retry_on ActiveRecord::RecordNotFound

  def perform(work_id:, source_bucket:, source_key:, target_bucket:, target_key:, size:, snapshot_id:)
    @work_id = work_id
    @snapshot_id = snapshot_id
    @source_bucket = source_bucket
    @source_key = source_key

    move_service = S3MoveService.new(work_id:, source_bucket:, source_key:, target_bucket:, target_key:, size:)

    etag = move_service.move # if there is an error and exception is raised

    snapshot.with_lock do
      snapshot.reload
      snapshot.mark_complete(target_key, etag)
    end

    # Once the last file has been deleted...
    if service.client_s3_files(reload: true, bucket_name: source_bucket).count == 0
      # delete the source directory...
      service.delete_s3_object(work.s3_object_key, bucket: source_bucket)

      # ...and create the preservation files
      work_preservation.preserve!
    end
  end

  def key
    @key ||= "/#{@source_bucket}/#{@source_key}"
  end

  def work
    @work ||= Work.find(@work_id)
  end

  def service
    @service ||= S3QueryService.new(work, work.files_mode)
  end

  def snapshot
    @snapshot ||= ApprovedUploadSnapshot.find(@snapshot_id)
  end

  def work_path
    @work_path ||= "#{work.doi}/#{work.id}"
  end

  def work_preservation
    @work_preservation ||= WorkPreservationService.new(work_id: @work_id, path: work_path)
  end
end
