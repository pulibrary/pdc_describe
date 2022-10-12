# frozen_string_literal: true
class NotificationMailer < ApplicationMailer
  include Rails.application.routes.url_helpers

  def build_message
    @user = params[:user]
    @work_activity = params[:work_activity]

    @subject = "[pdc-describe] New Notification"
    @message = @work_activity.message
    @url = work_url(@work_activity.work)

    mail(to: @user.email, subject: @subject)
  end
end
