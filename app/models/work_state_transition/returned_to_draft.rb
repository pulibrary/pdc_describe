# frozen_string_literal: true
module WorkStateTransition
  class ReturnedToDraft < Base
    def self.add_work_activity(work_id, current_user_id, user_tags)
      work_title = Work.find(work_id).title
      user_full_name = User.find(current_user_id).full_name
      message = "#{user_tags} #{user_full_name} at #{Time.now.utc} returned the following submission to you for revision: #{work_title}"
      activity = ReturnedToDraft.new(work_id:,  activity_type: WorkActivity::NOTIFICATION, message:, created_by_user_id: current_user_id)
      activity.save!
      activity.notify_users

      activity
    end
  end
end
