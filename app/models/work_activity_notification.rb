# frozen_string_literal: true

class WorkActivityNotification < ApplicationRecord
  belongs_to :work_activity
  belongs_to :user

  after_create do
    if user.email_messages_enabled? || direct_message?
      work = work_activity.work
      if work.group&.messages_enabled_for?(user: user) || direct_message?

        mailer = NotificationMailer.with(user: user, work_activity: work_activity)
        message = mailer.build_message
        message.deliver_later
      end
    end
  end

  private

    def direct_message?
      @direct_message ||= work_activity.activity_type == WorkActivity::MESSAGE && work_activity.message.include?("@#{user.uid}")
    end
end
