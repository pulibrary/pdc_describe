# frozen_string_literal: true
module ApplicationHelper
  ##
  # Attributes to add to the <html> tag (e.g. lang and dir)
  # @return [Hash]
  def html_tag_attributes
    { lang: I18n.locale }
  end

  def pre_curation_uploads_file_name(file:)
    value = file.filename.to_s
    return if value.blank?

    value[0..79]
  end
  alias post_curation_uploads_file_name pre_curation_uploads_file_name

  def ark_url(ark_value)
    return nil if ark_value.blank?
    # This was originally in Work#ark_url as: "https://ezid.cdlib.org/id/#{ark}"
    "http://arks.princeton.edu/#{ark_value}"
  end

  def doi_url(doi_value)
    return nil if doi_value.blank?
    "https://doi.org/#{doi_value}"
  end
end
