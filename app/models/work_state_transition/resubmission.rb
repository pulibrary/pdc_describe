# frozen_string_literal: true
module WorkStateTransition
  class Resubmission < Base
    def self.add_work_activity(work_id, current_user_id)
      super(work_id, "resubmitted from withdrawn", current_user_id, activity_type: WorkActivity::NOTIFICATION)
    end
  end
end
