# frozen_string_literal: true
module WorkStateTransition
  class DeletionMarker < Base
    def self.add_work_activity(work_id, current_user_id, _user_tags)
      super(work_id, "deletion marker", current_user_id, activity_type: WorkActivity::NOTIFICATION)
    end
  end
end
