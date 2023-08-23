# frozen_string_literal: true
class FormResourceDecorator
  attr_reader :resource, :current_user, :work

  SKIPPED_ROLES = ["DISTRIBUTOR", "FUNDER", "HOSTING_INSTITUTION", "REGISTRATION_AGENCY", "REGISTRATION_AUTHORITY", "RESEARCH GROUP"].freeze
  PPPL_FUNDER_NAME = "United States Department of Energy"
  PPPL_FUNDER_ROR = "https://ror.org/01bj3aw27"

  def initialize(work, current_user)
    @resource = work.resource
    @work = work
    @current_user = current_user
  end

  def funders
    @funders ||= begin
                   empty_row = if pppl? && resource.funders.empty?
                                 PDCMetadata::Funder.new(PPPL_FUNDER_ROR, PPPL_FUNDER_NAME, nil, nil)
                               end
                   resource.funders + [empty_row]
                 end
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

    def pppl?
      work.group == Group.plasma_laboratory
    end
end
