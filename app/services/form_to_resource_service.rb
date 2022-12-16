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
      process_related_objects(params, resource)
      process_titles(params, resource)
      process_creators(params, resource)
      process_contributors(params, resource)

      resource
    end

    private

      def process_curator_controlled(params, resource)
        resource.doi = params["doi"] if params["doi"].present?
        resource.ark = params["ark"] if params["ark"].present?
        resource.version_number = params["version_number"] if params["version_number"].present?
        resource.collection_tags = params["collection_tags"].split(",").map(&:strip) if params["collection_tags"]
        resource.resource_type = params["resource_type"] if params["resource_type"]
        resource.resource_type_general = params["resource_type_general"]&.to_sym if params["resource_type_general"]
      end

      def reset_resource_to_work(work)
        resource = PDCMetadata::Resource.new

        resource.doi = work.doi
        resource.ark = work.ark
        resource.collection_tags = work.resource.collection_tags || []
        resource
      end

      def process_titles(params, resource)
        resource.titles << PDCMetadata::Title.new(title: params["title_main"])
        (1..params["existing_title_count"].to_i).each do |i|
          if params["title_#{i}"].present?
            resource.titles << PDCMetadata::Title.new(title: params["title_#{i}"], title_type: params["title_type_#{i}"])
          end
        end

        (1..params["new_title_count"].to_i).each do |i|
          if params["new_title_#{i}"].present?
            resource.titles << PDCMetadata::Title.new(title: params["new_title_#{i}"], title_type: params["new_title_type_#{i}"])
          end
        end
      end

      def process_creators(params, resource)
        (1..params["creator_count"].to_i).each do |i|
          creator = new_creator(params["given_name_#{i}"], params["family_name_#{i}"], params["orcid_#{i}"], params["sequence_#{i}"])
          resource.creators << creator unless creator.nil?
        end
      end

      ## TODO: Do the right thing with blank form entries
      def process_related_objects(params, resource)
        (1..params["related_object_count"].to_i).each do |i|
          next if params["related_identifier_#{i}"].blank? && params["related_identifier_type_#{i}"].blank? # do not store blank related identifiers
          related_object = PDCMetadata::RelatedObject.new(
                            related_identifier: params["related_identifier_#{i}"],
                            related_identifier_type: params["related_identifier_type_#{i}"],
                            relation_type: params["relation_type_#{i}"]
                          )
          resource.related_objects << related_object
        end
      end

      def process_contributors(params, resource)
        (1..params["contributor_count"].to_i).each do |i|
          given_name = params["contributor_given_name_#{i}"]
          family_name = params["contributor_family_name_#{i}"]
          orcid = params["contributor_orcid_#{i}"]
          type = params["contributor_role_#{i}"]
          sequence = params["contributor_sequence_#{i}"]
          contributor = new_contributor(given_name, family_name, orcid, type, sequence)
          resource.contributors << contributor unless contributor.nil?
        end
      end

      def new_creator(given_name, family_name, orcid, sequence)
        return if family_name.blank? && given_name.blank? && orcid.blank?
        PDCMetadata::Creator.new_person(given_name, family_name, orcid, sequence)
      end

      def new_contributor(given_name, family_name, orcid, type, sequence)
        return if family_name.blank? && given_name.blank? && orcid.blank?
        PDCMetadata::Creator.new_contributor(given_name, family_name, orcid, type, sequence)
      end
  end
end
