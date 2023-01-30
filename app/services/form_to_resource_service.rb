# frozen_string_literal: true
class FormToResourceService
  class << self
    # Convert params into a resource
    #
    #  @param [Hash] params controller params to be converted
    #  @param [Work] work params will be applied to. Utilizes the work for old values if needed.
    #
    # @return [PDCMetadata::Resource] Fully formed resource containing updates from the user
    def convert(params, work)
      resource = reset_resource_to_work(work)

      resource.description = params.delete("description")
      resource.publisher = params.delete("publisher")
      resource.publication_year = params.delete("publication_year")
      resource.rights = PDCMetadata::Rights.find(params.delete("rights_identifier"))
      resource.keywords = (params.delete("keywords") || "").split(",").map(&:strip)
      resource.domains = params.delete("domains") || []

      add_curator_controlled(params, resource)
      add_titles(params, resource)
      add_related_objects(params, resource)
      add_creators(params, resource)
      add_contributors(params, resource)

      # Process funders
      # (New pattern: method modifies resource in place.)
      add_funders(params, resource)

      expected_params = ["work", "collection_id", "commit", "user_orcid", "user_given_name", "user_family_name", "controller", "action"]
      unexpected_params = params.keys - expected_params
      raise(StandardError, "Unexpected params: #{unexpected_params}") unless unexpected_params.empty?

      resource
    end

    private

      def reset_resource_to_work(work)
        resource = PDCMetadata::Resource.new

        resource.doi = work.doi
        resource.ark = work.ark
        resource.collection_tags = work.resource.collection_tags || []
        resource
      end

      def add_curator_controlled(params, resource)
        resource.doi = params.delete("doi")
        resource.ark = params.delete("ark")
        resource.version_number = params.delete("version_number")
        resource.collection_tags = (params.delete("collection_tags") || "").split(",").map(&:strip)
        resource.resource_type = params.delete("resource_type")
        resource.resource_type_general = params.delete("resource_type_general")
      end

      # Titles:

      def add_titles(params, resource)
        resource.titles << PDCMetadata::Title.new(title: params.delete("title_main"))
        resource.titles.concat((1..params.delete("existing_title_count").to_i).filter_map do |i|
          title = params.delete("title_#{i}")
          title_type = params.delete("title_type_#{i}")
          new_title(title, title_type)
        end)
        resource.titles.concat((1..params.delete("new_title_count").to_i).filter_map do |i|
          title = params.delete("new_title_#{i}")
          title_type = params.delete("new_title_type_#{i}")
          new_title(title, title_type)
        end)
      end

      def new_title(title, title_type)
        return if title.blank?
        PDCMetadata::Title.new(title: title, title_type: title_type)
      end

      # Related Objects:

      def add_related_objects(params, resource)
        resource.related_objects = (1..params.delete("related_object_count").to_i).filter_map do |i|
          related_identifier = params.delete("related_identifier_#{i}")
          related_identifier_type = params.delete("related_identifier_type_#{i}")
          relation_type = params.delete("relation_type_#{i}")
          new_related_object(related_identifier, related_identifier_type, relation_type)
        end
      end

      def new_related_object(related_identifier, related_identifier_type, relation_type)
        return if related_identifier.blank? && related_identifier_type.blank? && relation_type.blank?
        PDCMetadata::RelatedObject.new(related_identifier: related_identifier, related_identifier_type: related_identifier_type, relation_type: relation_type)
      end

      # Creators:

      def add_creators(params, resource)
        resource.creators = (1..params.delete("creator_count").to_i).filter_map do |i|
          given_name = params.delete("given_name_#{i}")
          family_name = params.delete("family_name_#{i}")
          orcid = params.delete("orcid_#{i}")
          sequence = params.delete("sequence_#{i}")
          new_creator(given_name, family_name, orcid, sequence)
        end
      end

      def new_creator(given_name, family_name, orcid, sequence)
        return if family_name.blank? && given_name.blank? && orcid.blank?
        PDCMetadata::Creator.new_person(given_name, family_name, orcid, sequence)
      end

      # Contributors:

      def add_contributors(params, resource)
        resource.contributors = (1..params.delete("contributor_count").to_i).filter_map do |i|
          given_name = params.delete("contributor_given_name_#{i}")
          family_name = params.delete("contributor_family_name_#{i}")
          orcid = params.delete("contributor_orcid_#{i}")
          type = params.delete("contributor_role_#{i}")
          sequence = params.delete("contributor_sequence_#{i}")
          new_contributor(given_name, family_name, orcid, type, sequence)
        end
      end

      def new_contributor(given_name, family_name, orcid, type, sequence)
        return if family_name.blank? && given_name.blank? && orcid.blank?
        PDCMetadata::Creator.new_contributor(given_name, family_name, orcid, type, sequence)
      end

      # Funders:

      def add_funders(params, resource)
        # (New pattern: Use rails param name conventions rather than numbering fields.)
        resource.funders = (params.delete(:funders) || []).filter_map do |funder|
          new_funder(funder[:ror], funder[:funder_name], funder[:award_number], funder[:award_uri])
        end
      end

      def new_funder(ror, funder_name, award_number, award_uri)
        return if funder_name.blank? && award_number.blank? && award_uri.blank?
        PDCMetadata::Funder.new(ror, funder_name, award_number, award_uri)
      end
  end
end
