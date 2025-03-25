# frozen_string_literal: true

class WorkActivityNotification < ApplicationRecord
  belongs_to :work_activity
  belongs_to :user

  after_create do
    if send_message?
      mailer = NotificationMailer.with(user:, work_activity:)
      work = work_activity.work
      delay = wait_time

      if work.state == "draft" && work.aasm.from_state == "awaiting_approval"
        reject_message = mailer.reject_message
        reject_message.deliver_later(wait: delay) unless Rails.env.development?
      else
        message = mailer.build_message
        message.deliver_later(wait: delay) unless Rails.env.development?
      end
    end
  end

  private

    def wait_time
      work = work_activity.work
      if work.state == "approved"
        90.minutes
      else
        10.seconds
      end
    end

    def direct_message?
      @direct_message ||= work_activity.activity_type == WorkActivity::MESSAGE && work_activity.message.include?("@#{user.uid}")
    end

    def send_message?
      return true if direct_message? # always send a direct message
      return false unless user.email_messages_enabled? # do not send message if all emails are disabled
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
