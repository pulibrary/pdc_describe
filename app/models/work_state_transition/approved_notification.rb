# frozen_string_literal: true
module WorkStateTransition
  class ApprovedNotification < BaseNotification
    private

      def send_messages
        update_email_sent("publish")
        mailer = NotificationMailer.with(user:, work_activity:)
        mailer.publish_message.deliver_later(wait: wait_time)
      end
  end
end
