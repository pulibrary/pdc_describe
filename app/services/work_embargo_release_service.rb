# frozen_string_literal: true

# A service to move work data from the post-curation bucket to the embargo bucket for currently embargoed works
#
class WorkEmbargoReleaseService
  attr_reader :work, :source_bucket, :target_bucket, :pul_s3_client

  # @param work_id [Integer] The ID of the work to preserve.
  def initialize(work:)
    @work = work
    @target_bucket = PULS3Client.post_curation_config[:bucket]
    @source_bucket = PULS3Client.embargo_config[:bucket]
    @pul_s3_client = S3QueryService.new(work, bucket_name: source_bucket)
  end

  # move the files
  def move
    files = pul_s3_client.client_s3_files(reload: true, bucket_name: source_bucket)
    snapshot = EmbargoReleaseSnapshot.new(work:)
    snapshot.store_files(files)
    snapshot.save
    files.each do |file|
      move_service = S3MoveService.new(work_id: work.id, source_bucket:, source_key: file.key, target_bucket:, target_key: file.key, size: file.size)

      etag = move_service.move # if there is an error and exception is raised

      snapshot.mark_complete(file.key, etag)
    end
    true
  end
end
