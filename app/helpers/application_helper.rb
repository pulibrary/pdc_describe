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
end
