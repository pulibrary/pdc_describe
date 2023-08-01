# frozen_string_literal: true
json.extract! activity_notification, :id, :created_at, :updated_at
json.url work_activity_notification_url(activity_notification, format: :json)
