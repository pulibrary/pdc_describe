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

  def wizard_mode?
    draft? && !migrated
  end

  def file_list_path
    return work_file_list_path("NONE") if @work.nil? || !@work.persisted?

    # This is a horrible hack to work-around the issue where Rails is not adding
    # the correct prefix to the URL in production and staging.
    if Rails.env.production? || Rails.env.staging?
      "/describe" + work_file_list_path(@work.id)
    else
      work_file_list_path(@work.id)
    end
  end

  def download_path
    return if @work.nil? || !@work.persisted?

    work_download_path(@work.id)
  end
end
