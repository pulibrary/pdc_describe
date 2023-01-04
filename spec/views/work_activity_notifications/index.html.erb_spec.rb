# frozen_string_literal: true
require "rails_helper"

RSpec.describe "work_activity_notifications/index", type: :view do
  let(:user) { FactoryBot.create :user }
  let(:work_activity) { FactoryBot.create(:work_activity, created_by_user_id: user.id, activity_type: WorkActivity::NOTIFICATION) }
  let(:valid_attributes) do
    {
      work_activity: work_activity,
      user: user
    }
  end

  before(:each) do
    assign(:work_activity_notifications, [
             WorkActivityNotification.create!(valid_attributes),
             WorkActivityNotification.create!(valid_attributes)
           ])
  end

  it "renders a list of work_activity_notifications" do
    render
  end
end
