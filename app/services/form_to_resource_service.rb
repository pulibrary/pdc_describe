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
      resource.domains = params["domains"] || []

      add_curator_controlled(params, resource)
      add_titles(params, resource)
      add_related_objects(params, resource)
      add_creators(params, resource)
      add_individual_contributors(params, resource)
      add_organizational_contributors(params, resource)
      add_funders(params, resource)

      resource
    end

    private

      def reset_resource_to_work(work)
        resource = PDCMetadata::Resource.new

        resource.doi = work.doi
        resource.ark = work.ark
        resource.migrated = work.resource.migrated
        resource.collection_tags = work.resource.collection_tags || []
        resource
      end

      def add_curator_controlled(params, resource)
        resource.doi = params["doi"] if params["doi"].present?
        resource.ark = params["ark"] if params["ark"].present?
        resource.version_number = params["version_number"] if params["version_number"].present?
        resource.collection_tags = params["collection_tags"].split(",").map(&:strip) if params["collection_tags"]
        resource.resource_type = params["resource_type"] if params["resource_type"]
        resource.resource_type_general = params["resource_type_general"] if params["resource_type_general"]
      end

      # Titles:

      def add_titles(params, resource)
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
        PDCMetadata::Title.new(title: title, title_type: title_type)
      end

      # Related Objects:

      def add_related_objects(params, resource)
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

      def add_creators(params, resource)
        resource.creators = params[:creators].each_with_index.filter_map do |creator, idx|
          new_creator(creator[:given_name], creator[:family_name], creator[:orcid], idx)
        end
      end

      def new_creator(given_name, family_name, orcid, sequence)
        return if family_name.blank? && given_name.blank? && orcid.blank?
        PDCMetadata::Creator.new_person(given_name, family_name, orcid, sequence)
      end

      # Individual Contributors:

      def add_individual_contributors(params, resource)
        resource.individual_contributors = (1..params["contributor_count"].to_i).filter_map do |i|
          given_name = params["contributor_given_name_#{i}"]
          family_name = params["contributor_family_name_#{i}"]
          orcid = params["contributor_orcid_#{i}"]
          type = params["contributor_role_#{i}"]
          sequence = params["contributor_sequence_#{i}"]
          new_individual_contributor(given_name, family_name, orcid, type, sequence)
        end
      end

      def new_individual_contributor(given_name, family_name, orcid, type, sequence)
        return if family_name.blank? && given_name.blank? && orcid.blank?
        PDCMetadata::Creator.new_individual_contributor(given_name, family_name, orcid, type, sequence)
      end

      # Organizational Contributors:

      def add_organizational_contributors(params, resource)
        # (New pattern: Use rails param name conventions rather than numbering fields.)
        resource.organizational_contributors = (params[:organizational_contributors] || []).filter_map do |contributor|
          value = contributor["value"]
          ror = contributor["ror"]
          type = contributor["type"]
          new_organizational_contributor(value, ror, type)
        end
      end

      def new_organizational_contributor(value, ror, type)
        return if value.blank? && ror.blank?
        PDCMetadata::Creator.new_organizational_contributor(value, ror, type)
      end

      # Funders:

      def add_funders(params, resource)
        resource.funders = (params[:funders] || []).filter_map do |funder|
          new_funder(funder[:ror], funder[:funder_name], funder[:award_number], funder[:award_uri])
        end
      end

      def new_funder(ror, funder_name, award_number, award_uri)
        return if funder_name.blank? && award_number.blank? && award_uri.blank?
        PDCMetadata::Funder.new(ror, funder_name, award_number, award_uri)
      end
  end
end
