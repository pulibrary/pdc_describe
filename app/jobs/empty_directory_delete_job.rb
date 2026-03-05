# frozen_string_literal: true
class EmptyDirectoryDeleteJob < ApplicationJob
  queue_as :default
  retry_on ActiveRecord::RecordNotFound

  def perform(work_id:, source_bucket:, source_key:, wait_time: 10)
    work = Work.find(work_id)
    service = S3QueryService.new(work, work.files_mode)

    if service.directory_empty(bucket: source_bucket, key: source_key)
      service.delete_s3_object(source_key, bucket: source_bucket)

      cleanup(work, service, source_bucket)
    else
      new_wait_time = wait_time * 10
      Rails.logger.warn("Directory is not empty #{source_bucket}#{source_key}.  Queuing the delete for #{new_wait_time} seconds from now")
      # queue the job for later, the files still have not moved
      EmptyDirectoryDeleteJob.set(wait: new_wait_time.seconds).perform_later(work_id:, source_bucket:, source_key:, wait_time: new_wait_time)
    end
  end

  private

    def cleanup(work, service, source_bucket)
      # Once the last directory has been deleted...
      if service.client_s3_files(reload: true, bucket_name: source_bucket).count == 0
        # delete the source directory...
        service.delete_s3_object(work.s3_object_key, bucket: source_bucket)

        # ...and create the preservation files
        work_preservation = WorkPreservationService.new(work_id: work.id, path: "#{work.doi}/#{work.id}")
        work_preservation.preserve!
      end
    end
end
