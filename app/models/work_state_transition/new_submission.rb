# frozen_string_literal: true
module WorkStateTransition
  class NewSubmission < Base
    def self.add_work_activity(work_id, current_user_id)
      work_title = Work.find(work_id).title
      work_url = data_commons_url(work_id)
      message = "[#{work_title}](#{work_url}) has been created."
      activity = NewSubmission.new(work_id:, activity_type: WorkActivity::NOTIFICATION, message:, created_by_user_id: current_user_id)
      activity.save!
      activity.notify_users

      activity
    end

    # explicitly email the submitter of the new submission activity the NewSubmissionNotification
    #   additionally use the generic notification class to notify the group administrators that a submission has been created
    def notify_users
      group_users.each { |user| WorkActivityNotification.create(work_activity_id: id, user_id: user.id) }
      NewSubmissionNotification.create(work_activity_id: id, user_id: work.created_by_user_id)
    end
  end
end
