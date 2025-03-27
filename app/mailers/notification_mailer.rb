# frozen_string_literal: true
class NotificationMailer < ApplicationMailer
  include Rails.application.routes.url_helpers

  def build_message
    @user = params[:user]
    @work_activity = params[:work_activity]

    @subject = "[pdc-describe] New Notification"
    @message = @work_activity.message
    @message_html = @work_activity.to_html
    @url = work_url(@work_activity.work)

    # Troubleshooting https://github.com/pulibrary/pdc_describe/issues/1783
    if @url.include?("/describe/describe/")
      Rails.logger.error("URL #{@url} included /describe/describe/ and was fixed. See https://github.com/pulibrary/pdc_describe/issues/1783")
      @url = @url.gsub("/describe/describe/", "/describe/")
    end

    mail(to: @user.email, subject: @subject)
  end

  def new_submission_message
    @user = params[:user]
    @work_activity = params[:work_activity]

    @subject = "[pdc-describe] New Submission Created"
    @message = @work_activity.message
    @message_html = @work_activity.to_html
    @url = work_url(@work_activity.work)

    # Troubleshooting https://github.com/pulibrary/pdc_describe/issues/1783
    if @url.include?("/describe/describe/")
      Rails.logger.error("URL #{@url} included /describe/describe/ and was fixed. See https://github.com/pulibrary/pdc_describe/issues/1783")
      @url = @url.gsub("/describe/describe/", "/describe/")
    end

    mail(to: @user.email, subject: @subject)
  end

  def review_message
    @user = params[:user]
    @work_activity = params[:work_activity]

    @subject = "[pdc-describe] Submission Ready for Review"
    @message = @work_activity.message
    @message_html = @work_activity.to_html
    @url = work_url(@work_activity.work)

    # Troubleshooting https://github.com/pulibrary/pdc_describe/issues/1783
    if @url.include?("/describe/describe/")
      Rails.logger.error("URL #{@url} included /describe/describe/ and was fixed. See https://github.com/pulibrary/pdc_describe/issues/1783")
      @url = @url.gsub("/describe/describe/", "/describe/")
    end

    mail(to: @user.email, subject: @subject)
  end

  def reject_message
    @user = params[:user]
    @work_activity = params[:work_activity]

    @subject = "[pdc-describe] Submission Returned"
    @message = @work_activity.message
    @message_html = @work_activity.to_html
    @url = work_url(@work_activity.work)

    # Troubleshooting https://github.com/pulibrary/pdc_describe/issues/1783
    if @url.include?("/describe/describe/")
      Rails.logger.error("URL #{@url} included /describe/describe/ and was fixed. See https://github.com/pulibrary/pdc_describe/issues/1783")
      @url = @url.gsub("/describe/describe/", "/describe/")
    end

    mail(to: @user.email, subject: @subject)
  end
end
