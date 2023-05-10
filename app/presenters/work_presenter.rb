# frozen_string_literal: true
class WorkPresenter
  attr_reader :work

  delegate :resource, to: :work

  def initialize(work:)
    @work = work
  end

  def description
    value = resource.description
    return if value.nil?
    Rinku.auto_link(value, :all, 'target="_blank"')
  end

  def related_objects_link_list
    ro = resource.related_objects
    ro.map { |a| format_related_object_links(a) }
  end

  # relation_type, identifier, link
  def format_related_object_links(related_object)
    rol = RelatedObjectLink.new
    rol.identifier = related_object.related_identifier
    rol.relation_type = related_object.relation_type
    rol.link = format_link(related_object.related_identifier, related_object.related_identifier_type)
    rol
  end

  # Turn an identifier into a link. This will vary for different kinds of related objects.
  # A DOI URL is not the same as an arXiv URL, for example.
  # For now, only format links for DOI and arXiv identifiers
  def format_link(id, id_type)
    return id if id.starts_with?("http")
    return "https://doi.org/#{id}" if id_type == "DOI"
    return "https://arxiv.org/abs/#{id}" if id_type == "arXiv"
    ""
  end
end
