# frozen_string_literal: true
class PULDatacite
  class << self
    # Determines whether or not a test DOI should be referenced
    # (this avoids requests to the DOI API endpoint for non-production deployments)
    # @return [Boolean]
    def publish_test_doi?
      (Rails.env.development? || Rails.env.test?) && Rails.configuration.datacite.user.blank?
    end
  end

  attr_reader :datacite_connection, :work, :metadata

  def initialize(work)
    @datacite_connection = Datacite::Client.new(username: Rails.configuration.datacite.user,
                                                password: Rails.configuration.datacite.password,
                                                host: Rails.configuration.datacite.host)
    @work = work
    @metadata = work.metadata
  end

  def draft_doi
    if PULDatacite.publish_test_doi?
      Rails.logger.info "Using hard-coded test DOI during development."
      "10.34770/tbd"
    else
      result = datacite_connection.autogenerate_doi(prefix: Rails.configuration.datacite.prefix)
      if result.success?
        result.success.doi
      else
        raise("Error generating DOI. #{result.failure.status} / #{result.failure.reason_phrase}")
      end
    end
  end

  def publish_doi(user)
    return Rails.logger.info("Publishing hard-coded test DOI during development.") if PULDatacite.publish_test_doi?

    if work.doi&.starts_with?(Rails.configuration.datacite.prefix)
      result = datacite_connection.update(id: work.doi, attributes: doi_attributes)
      if result.failure?
        resolved_user = curator_or_current_uid(user)
        message = "@#{resolved_user} Error publishing DOI. #{result.failure.status} / #{result.failure.reason_phrase}"
        WorkActivity.add_work_activity(work.id, message, user.id, activity_type: WorkActivity::DATACITE_ERROR)
      end
    elsif work.ark.blank? # we can not update the url anywhere
      Honeybadger.notify("Publishing for a DOI we do not own and no ARK is present: #{work.doi}")
    end
  rescue Faraday::ConnectionFailed
    sleep 1
    retry
  end

  # This is the url that should be used for ARK and DOI redirection. It will search the
  # index for the DOI and redirect the use appropriately.
  def doi_attribute_url
    "https://datacommons.princeton.edu/discovery/doi/#{work.doi}"
  end

  def curator_or_current_uid(user)
    persisted = if work.curator.nil?
                  user
                else
                  work.curator
                end
    persisted.uid
  end

  private

    def doi_attribute_resource
      PDCMetadata::Resource.new_from_jsonb(metadata)
    end

    def doi_attribute_xml
      unencoded = doi_attribute_resource.to_xml
      Base64.encode64(unencoded)
    end

    def doi_attributes
      {
        "event" => "publish",
        "xml" => doi_attribute_xml,
        "url" => doi_attribute_url
      }
    end
end
