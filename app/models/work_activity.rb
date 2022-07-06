# frozen_string_literal: true

class WorkActivity < ApplicationRecord
  belongs_to :work

  def self.add_system_activity(work_id, message, user_id)
    activity = WorkActivity.new(
      work_id: work_id,
      activity_type: "SYSTEM",
      message: message,
      created_by_user_id: user_id
    )
    activity.save!
    activity
  end

  def created_by_user
    return nil if created_by_user_id.nil?
    User.find(created_by_user_id)
  end
end
