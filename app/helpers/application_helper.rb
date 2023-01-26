# frozen_string_literal: true
module ApplicationHelper
  ##
  # Attributes to add to the <html> tag (e.g. lang and dir)
  # @return [Hash]
  def html_tag_attributes
    { lang: I18n.locale }
  end

  # rubocop:disable Rails/OutputSafety
  def person_orcid_link(name, orcid, add_separator)
    return if name.blank?

    icon_html = '<i class="bi bi-person-fill"></i>'
    separator = add_separator ? ";" : ""
    name_html = "#{name}#{separator}"
    if orcid.present?
      icon_html = '<img alt="ORCID logo" src="https://info.orcid.org/wp-content/uploads/2019/11/orcid_16x16.png" width="16" height="16" />'
      name_html = '<a href="https://orcid.org/' + orcid + '" target="_blank">' + name + "</a>" + separator
    end

    html = <<-HTML
    <span class="author-name">
      #{icon_html}
      #{name_html}
    </span>
    HTML
    html.html_safe
  end
  # rubocop:enable Rails/OutputSafety

  # rubocop:disable Rails/OutputSafety
  # rubocop:disable Metrics/MethodLength
  def individual_contributor_link(contributor, add_separator)
    return if contributor.value.blank?

    icon_html = ""
    separator = add_separator ? ";" : ""
    display_name = if contributor.type.present?
                     "#{contributor.value} (#{contributor.type.titleize})"
                   else
                     contributor.value
                   end
    if contributor.orcid.present?
      icon_html = '<img alt="ORCID logo" src="https://info.orcid.org/wp-content/uploads/2019/11/orcid_16x16.png" width="16" height="16" />'
      name_html = '<a href="https://orcid.org/' + contributor.orcid + '" target="_blank">' + display_name + "</a>" + separator
    else
      name_html = display_name + separator
    end

    html = <<-HTML
      <span class="author-name">
        #{icon_html}
        #{name_html}
      </span>
    HTML
    html.html_safe
  end
  # rubocop:enable Rails/OutputSafety
  # rubocop:enable Metrics/MethodLength

  # rubocop:disable Rails/OutputSafety
  # rubocop:disable Metrics/MethodLength
  def organizational_contributor_link(contributor, add_separator)
    # TODO: Copy-and-paste. Filed an issue to clean it all up:
    # https://github.com/pulibrary/pdc_describe/issues/906
    return if contributor.value.blank?

    icon_html = ""
    separator = add_separator ? ";" : ""
    display_name = if contributor.type.present?
                     "#{contributor.value} (#{contributor.type.titleize})"
                   else
                     contributor.value
                   end
    if contributor.ror.present?
      # Logo from https://ror.readme.io/docs/ror-id-display-guidelines-and-logos
      icon_html = '<img alt="ROR logo" src="https://raw.githubusercontent.com/ror-community/ror-logos/main/ror-icon-rgb.svg" height="24" />'
      name_html = '<a href="https://ror.org/' + contributor.ror + '" target="_blank">' + display_name + "</a>" + separator
    else
      name_html = display_name + separator
    end

    html = <<-HTML
      <span class="author-name">
        #{icon_html}
        #{name_html}
      </span>
    HTML
    html.html_safe
  end
  # rubocop:enable Rails/OutputSafety
  # rubocop:enable Metrics/MethodLength

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
