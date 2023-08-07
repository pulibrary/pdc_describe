# frozen_string_literal: true

FactoryBot.define do
  factory :work_activity do
    message { "test work activity message" }
    activity_type { WorkActivity::SYSTEM }
    created_by_user_id { FactoryBot.create(:user).id }
    work_id { FactoryBot.create(:draft_work).id }
  end

  factory :work_activity_message, class: "WorkActivity" do
    message { "test work activity message" }
    activity_type { WorkActivity::MESSAGE }
    created_by_user_id { FactoryBot.create(:user).id }
    work_id { FactoryBot.create(:draft_work).id }
  end
end
