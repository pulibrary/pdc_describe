# frozen_string_literal: true
class WorkAuditError < ::StandardError; end

# A service to create and store the preservation data for a given work.
# Currently it assumes this data will be stored in an AWS S3 bucket accessible with our AWS credentials.
# This preservation bucket is configured in our s3.yml file and we store it in a different availability region
# to make sure the data is properly distributed.
class WorkPreservationAuditService
  include Rails.application.routes.url_helpers

  attr_reader :date

  # @param date date works were approved to audit.
  def initialize(date: Time.zone.yesterday)
    @date = date
  end

  # Audits all works approved on the date and validates that their directory exists in preservation
  # @return [Boolean] true if all works from the date were present in preservation
  def audit!
    works = list_works
    work_status_list = works.map { |work| check_work(work) }
    empty_works = work_status_list.select { |work_status| work_status[:empty] }.pluck(:work)

    if empty_works.count > 0
      raise WorkAuditError, error_message(empty_works)
    end

    true
  end

  private

    def list_works
      approve_activities = WorkActivity.where(message: "marked as Approved", activity_type: WorkActivity::SYSTEM, created_at: date.all_day)
      approve_activities.map(&:work)
    end

    def check_work(work)
      s3service = S3QueryService.new(work, PULS3Client::PRESERVATION)
      status = s3service.directory_empty(bucket: s3service.bucket_name, key: s3service.prefix)
      { work:, empty: status }
    end

    def error_message(empty_works)
      return unless empty_works.count > 0

      error_links = empty_works.map { |work| work_link(work) }
      "Works Missing from preservation: #{error_links.join(', ')}"
    end

    def work_link(work)
      "<a href=\"#{work_url(work)}\">#{work.title} (#{work.doi})</a>"
    end
end
