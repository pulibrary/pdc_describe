# frozen_string_literal: true

# A service to move work data from the post-curation bucket to the embargo bucket for currently embargoed works
#
class WorkPublishService
  attr_reader :work, :current_user, :pul_s3_client

  # @param work_id [Integer] The ID of the work to preserve.
  def initialize(work:, current_user:)
    @work = work
    @current_user = current_user
    @pul_s3_client = S3QueryService.new(work, PULS3Client::PRECURATION)
  end

  # Copies the existing files from the pre-curation bucket to the target bucket (postcuration or embargo).
  #    Notice that the copy process happens at AWS (i.e. the files are not downloaded and re-uploaded).
  def publish
    s3_target_query_service = S3QueryService.new(work, target_mode)

    s3_dir = work.find_bucket_s3_dir(bucket_name: s3_target_query_service.bucket_name)
    raise(StandardError, "Attempting to publish a Work with an existing S3 Bucket directory for: #{target_bucket}/#{work.s3_object_key}") unless s3_dir.nil?

    # Copy the pre-curation S3 Objects to the target S3 Bucket.
    publish_files(current_user)
  end

  private

    def target_bucket
      if work.embargoed?
        PULS3Client.embargo_config[:bucket]
      else
        PULS3Client.post_curation_config[:bucket]
      end
    end

    def target_mode
      if work.embargoed?
        PULS3Client::EMBARGO
      else
        PULS3Client::POSTCURATION
      end
    end

    def publish_files(current_user)
      source_bucket = PULS3Client.pre_curation_config[:bucket]

      files_and_directories = pul_s3_client.client_s3_files(reload: true, bucket_name: source_bucket)

      files = files_and_directories.reject(&:is_folder)
      directories = files_and_directories.select(&:is_folder)

      snapshot = ApprovedUploadSnapshot.new(work:)
      snapshot.store_files(files, current_user:)
      snapshot.save

      files.each do |file|
        ApprovedFileMoveJob.perform_later(work_id: work.id, source_bucket:, source_key: file.key, target_bucket:,
                                          target_key: file.key, size: file.size, snapshot_id: snapshot.id)
      end

      directories.each do |dir|
        EmptyDirectoryDeleteJob.set(wait: 10.seconds).perform_later(work_id: work.id, source_bucket:, source_key: dir.key)
      end
      true
    end
end
