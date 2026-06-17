# frozen_string_literal: true
class WorkPresenter
  include Rails.application.routes.url_helpers

  attr_reader :work, :can_curate, :current_user

  delegate :resource, :group, :draft?, to: :work
  delegate :migrated, to: :resource

  def initialize(work:, current_user:)
    @work = work
    @current_user = current_user
    @can_curate = current_user&.can_admin?(group)
  end

  def changes
    WorkActivity.changes_for_work(work.id).order(created_at: :asc)
  end

  def messages
    WorkActivity.messages_for_work(work.id).order(created_at: :desc)
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

  def current_user_is_admin?
    current_user.has_role?(:group_admin, group)
  end

  def show_approve_button?
    work.awaiting_approval? && current_user_is_admin?
  end

  def show_revert_button?
    work.awaiting_approval? && (work.created_by_user_id == current_user.id || current_user_is_admin?)
  end

  def show_complete_button?
    draft? && (work.created_by_user_id == current_user.id || current_user_is_admin?)
  end

  def show_migrate_button?
    draft? && migrated && current_user_is_admin?
  end

  def edit_path
    if draft? && !migrated # wizard mode
      edit_work_wizard_path(work)
    else
      edit_work_path(work)
    end
  end

  def file_list_path
    return work_file_list_path("NONE") if @work.nil? || !@work.persisted?

    work_file_list_path(@work.id)
  end

  def download_path
    return if @work.nil? || !@work.persisted?

    work_download_path(@work.id)
  end

  private

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
      return "#{Rails.configuration.datacite.doi_url}#{id}" if id_type == "DOI"
      return "https://arxiv.org/abs/#{id}" if id_type == "arXiv"
      ""
    end
end
