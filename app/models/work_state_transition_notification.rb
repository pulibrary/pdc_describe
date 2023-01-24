# frozen_string_literal: true

# Connect with the curators of a work when an activity occurs
#
class WorkStateTransitionNotification
  attr_accessor :collection_administrators, :depositor, :to_state, :from_state,
                :work_url, :notification, :users, :id, :current_user_id, :work_title

  def initialize(work, current_user_id)
    @to_state = work.aasm.to_state
    @from_state = work.aasm.from_state
    @depositor = work.created_by_user
    @collection_administrators = work.collection.administrators.to_a
    @work_url = Rails.application.routes.url_helpers.work_url(work)
    @work_title = work.title
    @users = @collection_administrators | [@depositor] # Depositor may also be an admin, but should only be listed once.
    @notification = notification_for_transition
    @id = work.id
    @current_user_id = current_user_id
  end

  def send
    return if notification.nil?

    WorkActivity.add_work_activity(id, notification, current_user_id, activity_type: WorkActivity::NOTIFICATION)
  end

    private

      def notification_for_transition
        case to_state
        when :awaiting_approval
          "#{user_tags} [#{work_title}](#{work_url}) is ready for review."
        when :draft
          "#{user_tags} [#{work_title}](#{work_url}) has been created."
        when :approved
          "#{user_tags} [#{work_title}](#{work_url}) has been approved."
        end
      end

      def user_tags
        users.map { |admin| "@#{admin.uid}" }.join(", ")
      end
end
