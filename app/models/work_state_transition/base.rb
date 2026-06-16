# frozen_string_literal: true
module WorkStateTransition
  class Base < WorkActivity
    def work
      @work ||= Work.find(work_id)
    end

    def self.user_tags(work_id)
      work = Work.find(work_id)
      depositor = work.created_by_user
      group = work.group
      group_administrators = group.administrators
      groups_users_for_tags = ["@#{group.code}"]
      unless group_administrators.include?(depositor)
        groups_users_for_tags << "@#{depositor.uid}"
      end
      groups_users_for_tags.join(", ")
    end

    def notification_class
      "#{self.class.name}Notification".constantize
    end

    def notify_users
      group_users.each do |admin|
        next if work.created_by_user_id == admin.id
        notification_class.create(work_activity_id: id, user_id: admin.id)
      end
      notification_class.create(work_activity_id: id, user_id: work.created_by_user_id)
    end

    def group_users
      work.group.administrators.reject { |admin| admin.id == work.created_by_user_id }
    end

    def self.data_commons_url(work_id)
      url = if Rails.env.production?
              path = Rails.application.routes.url_helpers.work_path(work_id)
              "#{Rails.configuration.datacite.data_commons_url}#{path}"
            else
              Rails.application.routes.url_helpers.work_url(work_id)
            end
      url
    end
  end
end
