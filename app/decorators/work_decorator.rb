# frozen_string_literal: true
class WorkDecorator
  attr_reader :work, :changes, :messages, :can_curate, :current_user

  delegate :collection, to: :work

  def initialize(work, current_user)
    @work = work
    @current_user = current_user
    @changes =  WorkActivity.changes_for_work(work.id)
    @messages = WorkActivity.messages_for_work(work.id)
    @can_curate = current_user&.can_admin?(collection)
  end
end
