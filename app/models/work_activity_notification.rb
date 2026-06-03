# frozen_string_literal: true

class WorkActivityNotification < ApplicationRecord
  belongs_to :work_activity
  belongs_to :user

  after_create do
    if send_message?
      send_messages
    else
      update_email_sent("unsent")
    end
  end

  private

    def send_messages
      mailer = NotificationMailer.with(user:, work_activity:)
      # messages sent from the work
      if work_activity.activity_type == WorkActivity::MESSAGE
        update_email_sent("message")
        message = mailer.build_message
        message.deliver_later unless Rails.env.development?

      # state transition notifications
      elsif work_activity.activity_type == WorkActivity::NOTIFICATION
        update_email_sent("state_transition")
        mailer.build_message.deliver_later(wait: wait_time) unless Rails.env.development?

      # Error publishing DOI or Curator self assigned and assigned
      else
        update_email_sent("system")
        message = mailer.build_message
        message.deliver_later
      end
    end

    def update_email_sent(type)
      self.email_sent = { type:, email: user.email }
      save
    end

    def wait_time
      work = work_activity.work
      if work.state == "approved"
        90.minutes
      else
        10.seconds
      end
    end

    def check_from_state(work) # check the previous state of the work
      work_states = UserWork.where(work_id: work.id).sort_by(&:created_at).reverse
      if work_states.count > 1
        # states[0] is the current state, [1] is the previous state
        work_states[1].state.to_sym
      else
        :none
      end
    end

    # always send a direct message
    def direct_message?
      @direct_message ||= work_activity.activity_type == WorkActivity::MESSAGE && work_activity.message.include?("@#{user.uid}")
    end

    # always send a message to the curator about works they are curating
    def work_curator_message?
      @work_curator_message ||= work_activity.activity_type == WorkActivity::MESSAGE && user.id == work_activity.work.curator_user_id
    end

    # always send a message to the creator of the work
    def work_creator_message?
      @work_creator_message ||= work_activity.activity_type == WorkActivity::MESSAGE && user.id == work_activity.work.created_by_user_id
    end

    def send_message?
      return true if direct_message? || work_curator_message? || work_creator_message?
      return false unless user.email_messages_enabled?
      work = work_activity.work

      if work.resource.subcommunities.count > 1
        subcommunities_can_send = work.resource.subcommunities.map { |subcommunity| send_message_for_community?(subcommunity) }
        subcommunities_can_send.any?
      else
        send_message_for_community?(work.resource.subcommunities.first)
      end
    end

    def send_message_for_community?(subcommunity)
      group.messages_enabled_for?(user:, subcommunity:)
    end

    def group
      @group ||= work_activity.work.group
    end
end
