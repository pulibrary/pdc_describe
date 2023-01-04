# frozen_string_literal: true
class WorkActivityNotificationsController < ApplicationController
  before_action :set_work_activity_notification, only: %i[show]

  # GET /work_activity_notifications or /work_activity_notifications.json
  def index
    context = WorkActivityNotification.joins(:work_activity)
                                      .where(user: current_user, "work_activities.activity_type": WorkActivity::NOTIFICATION)
    @work_activity_notifications = context.where(read_at: nil).order(updated_at: :desc)
    @read_work_activity_notifications = context.where.not(read_at: nil).order(updated_at: :desc)
    @work_activity_notifications.each(&:mark_as_read!)
  end

  # GET /work_activity_notifications/1 or /work_activity_notifications/1.json
  def show; end

  private

    # Use callbacks to share common setup or constraints between actions.
    def set_work_activity_notification
      @work_activity_notification = WorkActivityNotification.find(params[:id])
    end
end
