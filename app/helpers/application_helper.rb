# frozen_string_literal: true
module ApplicationHelper
  ##
  # Attributes to add to the <html> tag (e.g. lang and dir)
  # @return [Hash]
  def html_tag_attributes
    { lang: I18n.locale }
  end

  def flash_notice
    value = flash[:notice]
    # rubocop:disable Rails/OutputSafety
    value.html_safe
    # rubocop:enable Rails/OutputSafety
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

  # Renders citation information APA-ish and BibTeX.
  # Notice that the only the APA style is visible, the BibTeX citataion is enabled via JavaScript.
  def render_cite_as(work)
    creators = work.resource.creators.map { |creator| "#{creator.family_name}, #{creator.given_name}" }
    citation = DatasetCitation.new(creators, [work.resource.publication_year], work.resource.titles.first.title, work.resource.resource_type, work.resource.publisher, work.resource.doi)
    return if citation.apa.nil?
    citation_html(work, citation)
  end

  def citation_html(work, citation)
    apa = citation.apa
    bibtex = citation.bibtex
    bibtex_html = html_escape(bibtex).gsub("\r\n", "<br/>").gsub("\t", "  ").gsub("  ", "&nbsp;&nbsp;")
    bibtex_text = html_escape(bibtex).gsub("\t", "  ")

    html = apa_section(apa) + "\n" + bibtex_section(work, bibtex_html, bibtex_text)
    # rubocop:disable Rails/OutputSafety
    html.html_safe
    # rubocop:enable Rails/OutputSafety
  end

  def bibtex_section(work, bibtex_html, bibtex_text)
    <<-HTML
    <div class="citation-bibtex-container hidden-element">
      <div class="bibtex-citation">#{bibtex_html}</div>
      <button id="copy-bibtext-citation-button" class="copy-citation-button btn btn-sm" data-style="BibTeX" data-text="#{bibtex_text}" title="Copy BibTeX citation to the clipboard">
        <i class="bi bi-clipboard" title="Copy BibTeX citation to the clipboard"></i>
        <span class="copy-citation-label-normal">COPY</span>
      </button>
      <button id="download-bibtex" class="btn btn-sm" data-url="#{work_bibtex_url(id: work.id)}" title="Download BibTeX citation to a file">
        <i class="bi bi-file-arrow-down" title="Download BibTeX citation to a file"></i>
        <span class="copy-citation-label-normal">DOWNLOAD</span>
      </button>
    </div>
  HTML
  end

  def apa_section(apa)
    <<-HTML
    <div class="citation-apa-container">
      <div class="apa-citation">#{html_escape(apa)}</div>
      <button id="copy-apa-citation-button" class="copy-citation-button btn btn-sm" data-style="APA" data-text="#{html_escape(apa)}" title="Copy citation to the clipboard">
        <i class="bi bi-clipboard" title="Copy citation to the clipboard"></i>
        <span class="copy-citation-label-normal">COPY</span>
      </button>
    </div>
    HTML
  end
end
