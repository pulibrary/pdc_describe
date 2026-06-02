# frozen_string_literal: true
module WorkStateTransition
  class Base < WorkActivity
    def work
      @work ||= Work.find(work_id)
    end

    def notification_class
      "#{self.class.name}Notification".constantize
    end

    def notify_users
      work.group.administrators.each do |admin|
        next if work.created_by_user_id == admin.id
        notification_class.create(work_activity_id: id, user_id: admin.id)
      end
      notification_class.create(work_activity_id: id, user_id: work.created_by_user_id)
    end

    def self.data_commons_url(work_id)
      url = if Rails.env.production?
              path = Rails.application.routes.url_helpers.work_path(work_id)
              "https://datacommons.princeton.edu#{path}"
            else
              Rails.application.routes.url_helpers.work_url(work_id)
            end
      url
    end
  end
end
