# frozen_string_literal: true
class ApprovedFileMoveJob < ApplicationJob
  queue_as :default

  def perform(work_id:, source_bucket:, source_key:, target_bucket:, target_key:, size:)
    work = Work.find(work_id)
    service = S3QueryService.new(Work.find(work_id), false)
    key = "/#{source_bucket}/#{source_key}"
    resp = service.copy_file(source_key: key, target_bucket:, target_key:, size:)

    unless resp.successful?
      raise "Error copying #{key} to #{target_bucket}/#{target_key} Response #{resp.to_json}"
    end
    status = service.check_file(bucket: target_bucket, key: target_key)
    unless status
      raise "File check was not valid #{source_key} to #{target_bucket}/#{target_key} Response #{status.to_json}"
    end
    service.delete_s3_object(source_key, bucket: source_bucket)

    # Once the last file has been deleted...
    if service.client_s3_files(reload: true, bucket_name: source_bucket).count == 0
      # delete the source directory...
      service.delete_s3_object(work.s3_object_key, bucket: source_bucket)

      # ...and create the preservation files in the preservation bucket
      work_preservation = WorkPreservationService.new(work_id: work_id, path: "#{work.doi}/#{work.id}")
      work_preservation.preserve!
    end
  end
end
