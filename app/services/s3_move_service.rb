# frozen_string_literal: true

class S3MoveService
  attr_reader :source_bucket, :source_key, :target_bucket, :target_key, :size, :service, :copy_source

  def initialize(work_id:, source_bucket:, source_key:, target_bucket:, target_key:, size:)
    @copy_source = [source_bucket, source_key].join("/")
    @source_key = source_key
    @source_bucket = source_bucket
    @target_bucket = target_bucket
    @target_key = target_key
    @size = size
    @service = S3QueryService.new(Work.find(work_id), bucket_name: source_bucket)
  end

  def move
    etag = copy_file # will raise exception if there is an error
    check_file # will raise exception if there is an error
    service.delete_s3_object(source_key, bucket: source_bucket)
    etag
  end

  private

    def copy_file
      resp = service.copy_file(source_key: copy_source, target_bucket:, target_key:, size:)
      unless resp.successful?
        raise "Error copying #{copy_source} to #{target_bucket}/#{target_key} Response #{resp.to_json}"
      end
      etag(resp)
    rescue Aws::S3::Errors::NoSuchKey => error
      if service.check_file(bucket: target_bucket, key: target_key)
        Rails.logger.warn("Trying to move a file that was already moved... #{copy_source} can not copy to #{target_bucket}/#{target_key}")
      else
        raise "Missing source file #{copy_source} can not copy to #{target_bucket}/#{target_key} Error: #{error}"
      end
    end

    def check_file
      status = service.check_file(bucket: target_bucket, key: target_key)
      unless status
        raise "File check was not valid #{copy_source} to #{target_bucket}/#{target_key} Response #{status.to_json}"
      end
    end

    def etag(resp)
      if resp.respond_to? :copy_object_result
        resp.copy_object_result.etag
      else
        resp.etag
      end.delete('"')
    end
end
