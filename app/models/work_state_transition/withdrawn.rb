# frozen_string_literal: true
module WorkStateTransition
  class Withdrawn < Base
    def self.add_work_activity(work_id, current_user_id)
      super(work_id, "withdrawn", current_user_id, activity_type: WorkActivity::NOTIFICATION)
    end
  end
end
