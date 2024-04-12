# frozen_string_literal: true
class WorkDecorator
  include Rails.application.routes.url_helpers

  attr_reader :work, :changes, :messages, :can_curate, :current_user

  delegate :group, :resource, :draft?, to: :work
  delegate :migrated, to: :resource

  def initialize(work, current_user)
    @work = work
    @current_user = current_user
    @changes =  WorkActivity.changes_for_work(work.id)
    @messages = WorkActivity.messages_for_work(work.id).order(created_at: :desc)
    @can_curate = current_user&.can_admin?(group)
  end

  def current_user_is_admin?
    current_user.has_role?(:group_admin, group)
  end

  def show_approve_button?
    work.awaiting_approval? && current_user_is_admin?
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
end
