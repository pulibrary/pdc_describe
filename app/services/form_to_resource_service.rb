# frozen_string_literal: true
class FormToResourceService
  class << self
    # Convert params into a resource
    #
    #  @param [Hash] params controller params to be converted
    #  @param [Work] work params will be applied to. Utilizes the work for old values if needed.
    #  @param [User] current_user user currently authorized with the system.  Utilizes the current_user to validate access.
    #
    # @return [PDCMetadata::Resource] Fully formed resource containing updates from the user
    def convert(params, work, current_user)
      resource = process_curator_controlled(params: params, work: work, current_user: current_user)
      resource.description = params["description"]
      resource.publisher = params["publisher"] if params["publisher"].present?
      resource.publication_year = params["publication_year"] if params["publication_year"].present?
      resource.rights = PDCMetadata::Rights.find(params["rights_identifier"])

      # Process the titles
      resource = process_titles(params, resource)

      # Process the creators
      resource = process_creators(params, resource)

      resource
    end

    private

      def process_curator_controlled(params:, work:, current_user:)
        resource = PDCMetadata::Resource.new
        if current_user.has_role?(:collection_admin, work.collection)
          resource.doi = params["doi"] if params["doi"].present?
          resource.ark = params["ark"] if params["ark"].present?
        end
        resource.doi ||= work.doi
        resource.ark ||= work.ark
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
        resource
      end

      def process_creators(params, resource)
        (1..params["creator_count"].to_i).each do |i|
          creator = new_creator(params["given_name_#{i}"], params["family_name_#{i}"], params["orcid_#{i}"], params["sequence_#{i}"])
          resource.creators << creator unless creator.nil?
        end
        resource
      end

      def new_creator(given_name, family_name, orcid, sequence)
        return if family_name.blank? && given_name.blank? && orcid.blank?
        PDCMetadata::Creator.new_person(given_name, family_name, orcid, sequence)
      end
  end
end
