# frozen_string_literal: true
require "rails_helper"

RSpec.describe "displaying notifications", type: :system, js: true do
  let(:work_activity) { FactoryBot.create :work_activity }
  let(:other_work_activity) { FactoryBot.create :work_activity, message: "other work activity" }
  let(:user) { work_activity.created_by_user }
  let(:other_user) { other_work_activity.created_by_user }
  let(:work_activity_notification) { WorkActivityNotification.create(work_activity_id: work_activity.id, user_id: user.id) }
  let(:other_work_activity_notification) { WorkActivityNotification.create(work_activity_id: other_work_activity.id, user_id: other_user.id) }
  let(:super_user) { FactoryBot.create :super_admin_user }

  it "displays work_activities for the user" do
    sign_in user
    work_activity_notification
    other_work_activity_notification
    visit "/"
    click_on user.uid
    click_on "Notifications"
    expect(page).to have_content(work_activity.message)
    expect(page).not_to have_content(other_work_activity.message)

    # we just ignore the user param for non super users
    visit work_activity_notifications_path(user: other_user.uid)
    expect(page).not_to have_content("Showing Notifications for #{other_user.uid}")
    expect(page).to have_content(work_activity.message)
    expect(page).not_to have_content(other_work_activity.message)
  end

  context "as a super user" do
    before do
      sign_in super_user
      work_activity_notification
      other_work_activity_notification
    end

    it "allows a super user to see any user activity notifications" do
      visit "/"
      click_on super_user.uid
      click_on "Notifications"
      expect(page).not_to have_content(work_activity.message)
      expect(page).not_to have_content(other_work_activity.message)
      visit work_activity_notifications_path(user: user.uid)
      expect(page).to have_content("Showing Notifications for #{user.uid}")
      expect(page).to have_content(work_activity.message)
      expect(page).not_to have_content(other_work_activity.message)
      visit work_activity_notifications_path(user: other_user.uid)
      expect(page).to have_content("Showing Notifications for #{other_user.uid}")
      expect(page).to have_content(other_work_activity.message)
      expect(page).not_to have_content(work_activity.message)
    end
  end
end
