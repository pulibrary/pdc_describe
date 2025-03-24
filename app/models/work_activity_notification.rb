# frozen_string_literal: true

class WorkActivityNotification < ApplicationRecord
  belongs_to :work_activity
  belongs_to :user

  after_create do
    if send_message?
      mailer = NotificationMailer.with(user:, work_activity:)
      message = mailer.build_message
      reject_message = mailer.reject_message
      work = work_activity.work
      if work.state == "approved"
        message.deliver_later(wait: 90.minutes) unless Rails.env.development?
      elsif work.state == "draft" && work_activity.message.include?("revision")
        reject_message.deliver_later(wait: 10.seconds) unless Rails.env.development?
      else
        message.deliver_later(wait: 10.seconds) unless Rails.env.development?
      end
    end
  end

  private

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
