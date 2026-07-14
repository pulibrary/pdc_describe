# frozen_string_literal: true
module WorkStateTransition
  class AwaitingApproval < Base
    def self.add_work_activity(work_id, current_user_id)
      work_title = Work.find(work_id).title
      work_url = data_commons_url(work_id)
      message = "#{user_tags(work_id)} [#{work_title}](#{work_url}) is ready for review."
      activity = AwaitingApproval.new(work_id:, activity_type: WorkActivity::NOTIFICATION, message:, created_by_user_id: current_user_id)
      activity.save!
      activity.notify_users

      activity
    end
  end
end
