# frozen_string_literal: true
class FormResourceDecorator
  attr_reader :resource, :current_user

  SKIPPED_ROLES = ["DISTRIBUTOR", "FUNDER", "HOSTING_INSTITUTION", "REGISTRATION_AGENCY", "REGISTRATION_AUTHORITY", "RESEARCH GROUP"].freeze

  def initialize(resource, current_user)
    @resource = resource
    @current_user = current_user
  end

  def funders
    resource.funders + [nil]
  end

  def individual_contributors
    item_or_nil_array(resource.individual_contributors)
  end

  def contributor_types
    @contributor_types ||= Datacite::Mapping::ContributorType.to_a.reject { |role| SKIPPED_ROLES.include? role.key.to_s }
    @contributor_types
  end

  def related_objects
    item_or_nil_array(resource.related_objects)
  end

  def creators
    item_or_nil_array(resource.creators)
  end

  def organizational_contributors
    resource.organizational_contributors + [nil]
  end

  private

    def item_or_nil_array(item)
      if item.empty?
        [nil]
      else
        item
      end
    end
end
