# frozen_string_literal: true
class WorkActivityNotificationsController < ApplicationController
  before_action :set_activity_notification, only: %i[show]

  # GET /activity_notifications or /activity_notifications.json
  def index
    @work_activity_notifications = WorkActivityNotification.where(user_id: user.id).order(created_at: :desc)
  end

  # GET /activity_notifications/1 or /activity_notifications/1.json
  def show; end

  private

    # Use callbacks to share common setup or constraints between actions.
    def set_activity_notification
      @work_activity_notification = WorkActivityNotification.find(params[:id])
    end

    def user
      @user ||= if user_param
                  User.find_by(uid: user_param) || current_user
                else
                  current_user
                end
    end

    def user_param
      return nil unless current_user.super_admin?
      @user_param ||= params[:user]
    end
end
