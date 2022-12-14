# frozen_string_literal: true

class WorkActivityNotification < ApplicationRecord
  belongs_to :work_activity
  belongs_to :user

  after_create do
    if user.email_messages_enabled?
      work = work_activity.work
      if work.collection&.messages_enabled_for?(user: user)

        mailer = NotificationMailer.with(user: user, work_activity: work_activity)

        #####
        # Do not separate build_message and deliver_later on separate lines
        #  You will get an error like `You've accessed the message before...` in production/staging
        #  I spent a long time trying to replicate the error in a test, but could not
        mailer.build_message.deliver_later
        #####
      end
    end
  end
end
