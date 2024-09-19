# frozen_string_literal: true

# Connect with the curators of a work when an activity occurs
#
class WorkStateTransitionNotification
  attr_reader :group_administrators, :depositor, :to_state, :from_state, :group,
                :work_url, :notification, :users, :id, :current_user_id, :work_title

  def initialize(work, current_user_id)
    @to_state = work.aasm.to_state
    @from_state = work.aasm.from_state
    @depositor = work.created_by_user
    @group = work.group
    @group_administrators = group.administrators.to_a
    @work_url = Rails.application.routes.url_helpers.work_url(work)

    # Troubleshooting https://github.com/pulibrary/pdc_describe/issues/1783
    if @work_url.include?("/describe/describe/")
      Rails.logger.error("URL #{@work_url} included /describe/describe/ and was fixed. See https://github.com/pulibrary/pdc_describe/issues/1783")
      @work_url = @work_url.gsub("/describe/describe/", "/describe/")
    end

    @work_title = work.title
    @notification = notification_for_transition
    @id = work.id

    raise(NotImplementedError, "Invalid user ID provided.") if current_user_id.nil?
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
        @user_tags = begin
                      groups_users_for_tags = ["@#{group.code}"]
                      unless group_administrators.include?(depositor)
                        groups_users_for_tags << "@#{depositor.uid}"
                      end

                      groups_users_for_tags.join(", ")
                    end
      end
end
