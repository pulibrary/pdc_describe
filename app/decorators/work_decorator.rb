# frozen_string_literal: true
class WorkDecorator
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

  def show_approve_button?
    work.awaiting_approval? && current_user.has_role?(:group_admin, group)
  end

  def show_complete_button?
    draft? && work.created_by_user_id == current_user.id
  end

  def show_migrate_button?
    draft? && migrated && current_user.has_role?(:group_admin, group)
  end

  def wizard_mode?
    draft? && !migrated
  end
end
