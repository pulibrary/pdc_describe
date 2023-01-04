# frozen_string_literal: true
require "rails_helper"

RSpec.describe "work_activity_notifications/show", type: :view do
  let(:user) { FactoryBot.create :user }
  let(:work_activity) { FactoryBot.create(:work_activity, created_by_user_id: user.id, activity_type: WorkActivity::NOTIFICATION) }
  let(:valid_attributes) do
    {
      work_activity: work_activity,
      user: user
    }
  end

  before(:each) do
    @work_activity_notification = assign(:work_activity_notification, WorkActivityNotification.create!(valid_attributes))
  end

  it "renders attributes in <p>" do
    render
  end
end
