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

      resource.description = params["description"]
      resource.publisher = params["publisher"] if params["publisher"].present?
      resource.publication_year = params["publication_year"] if params["publication_year"].present?
      resource.rights = PDCMetadata::Rights.find(params["rights_identifier"])
      resource.keywords = (params["keywords"] || "").split(",").map(&:strip)
      resource.funder_name = params["funder_name"]
      resource.award_number = params["award_number"]
      resource.award_uri = params["award_uri"]

      process_curator_controlled(params, resource)
      process_titles(params, resource)
      process_related_objects(params, resource)
      process_creators(params, resource)
      process_contributors(params, resource)

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

      def process_curator_controlled(params, resource)
        resource.doi = params["doi"] if params["doi"].present?
        resource.ark = params["ark"] if params["ark"].present?
        resource.version_number = params["version_number"] if params["version_number"].present?
        resource.collection_tags = params["collection_tags"].split(",").map(&:strip) if params["collection_tags"]
        resource.resource_type = params["resource_type"] if params["resource_type"]
        resource.resource_type_general = params["resource_type_general"]&.to_sym if params["resource_type_general"]
      end

      # Titles:

      def process_titles(params, resource)
        resource.titles << PDCMetadata::Title.new(title: params["title_main"])
        resource.titles.concat((1..params["existing_title_count"].to_i).filter_map do |i|
          title = params["title_#{i}"]
          title_type = params["title_type_#{i}"]
          new_title(title, title_type)
        end)
        resource.titles.concat((1..params["new_title_count"].to_i).filter_map do |i|
          title = params["new_title_#{i}"]
          title_type = params["new_title_type_#{i}"]
          new_title(title, title_type)
        end)
      end

      def new_title(title, title_type)
        return if title.blank?
        PDCMetadata::Title.new(title, title_type)
      end

      # Related Objects:

      def process_related_objects(params, resource)
        resource.related_objects = (1..params["related_object_count"].to_i).filter_map do |i|
          related_identifier = params["related_identifier_#{i}"]
          related_identifier_type = params["related_identifier_type_#{i}"]
          relation_type = params["relation_type_#{i}"]
          new_related_object(related_identifier, related_identifier_type, relation_type)
        end
      end

      def new_related_object(related_identifier, related_identifier_type, relation_type)
        return if related_identifier.blank? && related_identifier_type.blank? && relation_type.blank?
        PDCMetadata::RelatedObject.new(related_identifier: related_identifier, related_identifier_type: related_identifier_type, relation_type: relation_type)
      end

      # Creators:

      def process_creators(params, resource)
        resource.creators = (1..params["creator_count"].to_i).filter_map do |i|
          given_name = params["given_name_#{i}"]
          family_name = params["family_name_#{i}"]
          orcid = params["orcid_#{i}"]
          sequence = params["sequence_#{i}"]
          new_creator(given_name, family_name, orcid, sequence)
        end
      end

      def new_creator(given_name, family_name, orcid, sequence)
        return if family_name.blank? && given_name.blank? && orcid.blank?
        PDCMetadata::Creator.new_person(given_name, family_name, orcid, sequence)
      end

      # Contributors:

      def process_contributors(params, resource)
        resource.contributors = (1..params["contributor_count"].to_i).filter_map do |i|
          given_name = params["contributor_given_name_#{i}"]
          family_name = params["contributor_family_name_#{i}"]
          orcid = params["contributor_orcid_#{i}"]
          type = params["contributor_role_#{i}"]
          sequence = params["contributor_sequence_#{i}"]
          new_contributor(given_name, family_name, orcid, type, sequence)
        end
      end

      def new_contributor(given_name, family_name, orcid, type, sequence)
        return if family_name.blank? && given_name.blank? && orcid.blank?
        PDCMetadata::Creator.new_contributor(given_name, family_name, orcid, type, sequence)
      end
  end
end
