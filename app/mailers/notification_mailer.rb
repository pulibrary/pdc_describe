# frozen_string_literal: true
class NotificationMailer < ApplicationMailer
  include Rails.application.routes.url_helpers

  def build_message
    @user = params[:user]
    @work_activity = params[:work_activity]

    @subject = "[pdc-describe] New Notification"
    @message = @work_activity.message
    @message_html = @work_activity.to_html
    @url = data_commons_url(@work_activity.work)

    mail(to: @user.email, subject: @subject)
  end

  def new_submission_message
    @user = params[:user]
    @work_activity = params[:work_activity]
    @work_title = @work_activity.work.title.nil? ? "Untitled Work" : @work_activity.work.title

    @subject = "[pdc-describe] New Submission Created"
    @url = data_commons_url(@work_activity.work)
    @doi_url = @work_activity.work.doi_url

    mail(to: @user.email, subject: @subject)
  end

  def review_message
    @user = params[:user]
    @work_activity = params[:work_activity]

    @subject = "[pdc-describe] Submission Ready for Review"
    @url = data_commons_url(@work_activity.work)

    mail(to: @user.email, subject: @subject)
  end

  def reject_message
    @user = params[:user]
    @work_activity = params[:work_activity]
    # Get the title of the work for the email message
    @work_title = @work_activity.work.title.nil? ? "Untitled Work" : @work_activity.work.title

    @subject = "[pdc-describe] Submission Returned"
    @message = @work_activity.message
    @message_html = @work_activity.to_html
    @url = data_commons_url(@work_activity.work)

    mail(to: @user.email, subject: @subject)
  end

  def data_commons_url(work)
    url = if Rails.env.production?
            path = work_path(work)

            "https://datacommons.princeton.edu#{path}"
          else
            work_url(work)
          end
    check_url(url)
  end

  def check_url(url)
    # Troubleshooting https://github.com/pulibrary/pdc_describe/issues/1783
    if url.include?("/describe/describe/")
      Rails.logger.error("URL #{url} included /describe/describe/ and was fixed. See https://github.com/pulibrary/pdc_describe/issues/1783")
      url = url.gsub("/describe/describe/", "/describe/")
    end
    url
  end
end
