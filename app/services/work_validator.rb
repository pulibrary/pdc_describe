# frozen_string_literal: true
class WorkValidator
  attr_reader :work

  delegate :errors, :metadata, :resource, :ark, :doi, :user_entered_doi, :id, :group,
           :pre_curation_uploads, :post_curation_uploads, to: :work

  def initialize(work)
    @work = work
  end

  def valid?
    if work.none?
      validate_ids
    elsif work.draft?
      valid_to_draft
    else
      valid_to_submit
    end
  end

  def valid_to_draft(*)
    errors.add(:base, "Must provide a title") if resource.main_title.blank?
    validate_ark
    validate_creators
    validate_related_objects if resource.present? && !resource.related_objects.empty?
    errors.count == 0
  end

  def valid_to_submit(*args)
    valid_to_draft(args)
    validate_metadata
    if errors.count == 0
      valid_datacite? # test if the datacite update will be valid
    end
    errors.count == 0
  end

  def valid_to_approve(user)
    if resource.doi.blank?
      errors.add :base, "DOI must be present for a work to be approved"
    end
    valid_to_submit(user)
    unless user.has_role? :group_admin, group
      errors.add :base, "Unauthorized to Approve"
    end
    if pre_curation_uploads.empty? && post_curation_uploads.empty?
      errors.add :base, "Uploads must be present for a work to be approved"
    end
    errors.count == 0
  end

  def valid_datacite?
    datacite_serialization = resource.datacite_serialization
    datacite_serialization.valid?
    datacite_serialization.errors.each { |error| errors.add(:base, error) }
    errors.count == 0
  rescue ArgumentError => error
    argument_path = error.backtrace_locations.first.path
    argument_file = argument_path.split("/").last
    argument_name = argument_file.split(".").first
    errors.add(:base, "#{argument_name.titleize}: #{error.message}")
    false
  end

  private

    def validate_ark
      return if ark.blank?
      return false unless unique_ark
      first_save = id.blank?
      changed_value = metadata["ark"] != ark
      if first_save || changed_value
        errors.add(:base, "Invalid ARK provided for the Work: #{ark}") unless Ark.valid?(ark)
      end
    end

    def validate_related_objects
      return if resource.related_objects.empty?
      invalid = resource.related_objects.reject(&:valid?)
      if invalid.count.positive?
        related_object_errors = "Related Objects are invalid: "
        prev_errors = errors.to_a
        prev_related_object_errors = prev_errors.map { |e| e.include?(related_object_errors) }.reduce(:|)

        errors.add(:base, "#{related_object_errors}#{invalid.map(&:errors).join(', ')}") unless prev_related_object_errors
      end
    end

    def validate_creators
      if resource.creators.count == 0
        errors.add(:base, "Must provide at least one Creator")
      else
        resource.creators.each do |creator|
          if creator.orcid.present? && Orcid.invalid?(creator.orcid)
            errors.add(:base, "ORCID for creator #{creator.value} is not in format 0000-0000-0000-0000")
          end
        end
      end
    end

    def validate_required_metadata
      return if metadata.blank?
      errors.add(:base, "Must provide a title") if resource.main_title.blank?
      validate_creators
    end

    def validate_doi
      return true unless user_entered_doi
      return false unless unique_doi
      if /^10.\d{4,9}\/[-._;()\/:a-z0-9\-]+$/.match?(doi.downcase)
        response = Faraday.get("#{Rails.configuration.datacite.doi_url}#{doi}")
        errors.add(:base, "Invalid DOI: can not verify it's authenticity") unless response.success? || response.status == 302
      else
        errors.add(:base, "Invalid DOI: does not match format")
      end
      errors.count == 0
    end

    def unique_ark
      return true if ark.blank?
      other_record = Work.find_by_ark(ark)
      return true if other_record == work
      errors.add(:base, "Invalid ARK: It has already been applied to another work #{other_record.id}")
      false
    rescue ActiveRecord::RecordNotFound
      true
    end

    def validate_ids
      validate_doi
      unique_ark
    end

    def unique_doi
      other_record = Work.find_by_doi(doi)
      return true if other_record == work
      errors.add(:base, "Invalid DOI: It has already been applied to another work #{other_record.id}")
      false
    rescue ActiveRecord::RecordNotFound
      true
    end

    def validate_metadata
      return if metadata.blank?
      validate_required_metadata
      errors.add(:base, "Must provide a description") if resource.description.blank?
      errors.add(:base, "Must indicate the Publisher") if resource.publisher.blank?
      errors.add(:base, "Must indicate the Publication Year") if resource.publication_year.blank?
      errors.add(:base, "Must indicate at least one Rights statement") if resource.rights_many.count == 0
      errors.add(:base, "Must provide a Version number") if resource.version_number.blank?
      validate_related_objects
    end
end
