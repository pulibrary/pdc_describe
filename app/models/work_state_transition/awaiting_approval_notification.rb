# frozen_string_literal: true
module WorkStateTransition
  class AwaitingApprovalNotification < BaseNotification
    private

      def send_messages
        update_email_sent("review")
        mailer = NotificationMailer.with(user:, work_activity:)
        mailer.review_message.deliver_later(wait: wait_time)
      end
  end
end
