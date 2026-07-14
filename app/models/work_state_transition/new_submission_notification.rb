# frozen_string_literal: true
module WorkStateTransition
  class NewSubmissionNotification < BaseNotification
    private

      def send_messages
        update_email_sent("new_submission")
        mailer = NotificationMailer.with(user:, work_activity:)
        mailer.new_submission_message.deliver_later
      end
  end
end
