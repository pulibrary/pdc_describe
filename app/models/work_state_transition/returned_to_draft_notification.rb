# frozen_string_literal: true
module WorkStateTransition
  class ReturnedToDraftNotification < BaseNotification
    private

      def send_messages
        update_email_sent("reject")
        mailer = NotificationMailer.with(user:, work_activity:)
        mailer.reject_message.deliver_later(wait: wait_time)
      end
  end
end
