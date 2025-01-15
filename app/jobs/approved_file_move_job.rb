# frozen_string_literal: true
class ApprovedFileMoveJob < ApplicationJob
  queue_as :default
  retry_on ActiveRecord::RecordNotFound

  def perform(work_id:, source_bucket:, source_key:, target_bucket:, target_key:, size:, snapshot_id:)
    @work_id = work_id
    @snapshot_id = snapshot_id
    @source_bucket = source_bucket
    @source_key = source_key

    begin
      resp = service.copy_file(source_key: key, target_bucket:, target_key:, size:)
      unless resp.successful?
        raise "Error copying #{key} to #{target_bucket}/#{target_key} Response #{resp.to_json}"
      end
    rescue Aws::S3::Errors::NoSuchKey => error
      status = service.check_file(bucket: source_bucket, key:)
      unless status
        raise "Missing source file #{key} can not copy to #{target_bucket}/#{target_key} Error: #{error}"
      end
    end

    status = service.check_file(bucket: target_bucket, key: target_key)
    unless status
      raise "File check was not valid #{source_key} to #{target_bucket}/#{target_key} Response #{status.to_json}"
    end
    etag = if resp.respond_to? :copy_object_result
             resp.copy_object_result.etag
           else
             resp.etag
           end.delete('"')

    # raise("Failed to resolve the ApprovedUploadSnapshot for #{@snapshot_id}") if snapshot.nil?

    snapshot.with_lock do
      snapshot.reload
      snapshot.mark_complete(target_key, etag)
    end
    service.delete_s3_object(source_key, bucket: source_bucket)

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
    @service ||= S3QueryService.new(work, "postcuration")
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
