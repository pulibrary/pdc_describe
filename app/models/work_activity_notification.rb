# frozen_string_literal: true

class WorkActivityNotification < ApplicationRecord
  belongs_to :work_activity
  belongs_to :user

  after_create do
    if user.email_messages_enabled?
      mailer = NotificationMailer.with(user: user, work_activity: work_activity)
      message = mailer.build_message
      message.deliver_later
    end
  end
end
