# frozen_string_literal: true
module WorkStateTransition
  class ApprovedNotification < BaseNotification
    private

      def send_messages
        update_email_sent("publish")
        mailer = NotificationMailer.with(user:, work_activity:)

        # no waiting in development as there is no queue
        if Rails.env.development?
          mailer.publish_message.deliver_later

        # in other environments, wait 90 minutes to allow for the item to be published in Discovery
        else
          mailer.publish_message.deliver_later(wait: 90.minutes)
        end
      end
  end
end
