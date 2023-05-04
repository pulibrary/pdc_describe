# frozen_string_literal: true
class DspaceFileCopyJob < ApplicationJob
  queue_as :default

  def perform(dspace_doi, s3_key, s3_size, work_id)
    work = Work.find(work_id)
    dspace_bucket_name = Rails.configuration.s3.dspace[:bucket]
    new_key = s3_key.gsub("#{dspace_doi}/".tr(".", "-"), work.s3_query_service.prefix)
    resp = if s3_size == 0
             work.s3_query_service.copy_directory(source_key: "#{dspace_bucket_name}/#{s3_key}",
                                                  target_bucket: work.s3_query_service.bucket_name,
                                                  target_key: new_key)
           else
             work.s3_query_service.copy_file(source_key: "#{dspace_bucket_name}/#{s3_key}",
                                             target_bucket: work.s3_query_service.bucket_name,
                                             target_key: new_key, size: s3_size)
           end
    unless resp.successful?
      raise "Error copying #{s3_key} to work #{work_id} Response #{resp}"
    end
  end
end
