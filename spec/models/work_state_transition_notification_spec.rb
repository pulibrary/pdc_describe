# frozen_string_literal: true
require "rails_helper"

describe WorkStateTransitionNotification, type: :model do
  let(:user) { FactoryBot.create :user, groups_to_admin: [work.group] }
  let(:work) { FactoryBot.create(:draft_work) }
  let(:transition_notification) { described_class.new(work, user.id) }

  describe "#send" do
    let(:to_state) { :draft }
    let(:from_state) { :none }
    before do
      aasm = work.aasm
      allow(aasm).to receive(:from_state).and_return(from_state)
      allow(aasm).to receive(:to_state).and_return(to_state)
    end

    it "creates WorkActivityNotifications for each user" do
      expect do
        transition_notification.send
      end.to change(WorkActivityNotification, :count)
        .by(2).and change(WorkActivity, :count).by(1)

      group_notification = WorkActivityNotification.first
      user_notification = WorkActivityNotification.last
      activity = user_notification.work_activity
      expect(user_notification.work_activity).to eq(group_notification.work_activity)
      expect(activity.message).to include("has been created")
      expect(activity.activity_type).to eq(WorkActivity::NOTIFICATION)
      expect(activity.work_id).to eq(work.id)
      expect(group_notification.user_id).to eq(user.id)
      expect(group_notification.email_sent).to eq({ "type" => "new_submission", "email" => user.email })
      expect(user_notification.email_sent).to eq({ "type" => "new_submission", "email" => work.created_by_user.email })
      expect(user_notification.user_id).to eq(work.created_by_user_id)
    end

    context "when the work is submitted for review" do
      let(:to_state) { :awaiting_approval }
      let(:from_state) { :draft }

      it "creates WorkActivityNotifications for each user" do
        expect do
          transition_notification.send
        end.to change(WorkActivityNotification, :count)
          .by(2).and change(WorkActivity, :count).by(1)

        group_notification = WorkActivityNotification.first
        user_notification = WorkActivityNotification.last
        activity = user_notification.work_activity
        expect(user_notification.work_activity).to eq(group_notification.work_activity)
        expect(activity.message).to include("is ready for review")
        expect(activity.activity_type).to eq(WorkActivity::NOTIFICATION)
        expect(activity.work_id).to eq(work.id)
        expect(group_notification.user_id).to eq(user.id)
        expect(group_notification.email_sent).to eq({ "type" => "review", "email" => user.email })
        expect(user_notification.email_sent).to eq({ "type" => "review", "email" => work.created_by_user.email })
        expect(user_notification.user_id).to eq(work.created_by_user_id)
      end
    end

    context "when the work is returned to draft" do
      let(:to_state) { :draft }
      let(:from_state) { :awaiting_approval }

      it "creates WorkActivityNotifications for each user" do
        expect do
          transition_notification.send
        end.to change(WorkActivityNotification, :count)
          .by(2).and change(WorkActivity, :count).by(1)

        group_notification = WorkActivityNotification.first
        user_notification = WorkActivityNotification.last
        activity = user_notification.work_activity
        expect(user_notification.work_activity).to eq(group_notification.work_activity)
        expect(activity.message).to include("returned the following submission to you for revision")
        expect(activity.activity_type).to eq(WorkActivity::NOTIFICATION)
        expect(activity.work_id).to eq(work.id)
        expect(group_notification.user_id).to eq(user.id)
        expect(group_notification.email_sent).to eq({ "type" => "reject", "email" => user.email })
        expect(user_notification.email_sent).to eq({ "type" => "reject", "email" => work.created_by_user.email })
        expect(user_notification.user_id).to eq(work.created_by_user_id)
      end
    end

    context "when the work is approved" do
      let(:to_state) { :approved }
      let(:from_state) { :awaiting_approval }

      it "creates WorkActivityNotifications for each user" do
        expect do
          transition_notification.send
        end.to change(WorkActivityNotification, :count)
          .by(2).and change(WorkActivity, :count).by(1)

        group_notification = WorkActivityNotification.first
        user_notification = WorkActivityNotification.last
        activity = user_notification.work_activity
        expect(user_notification.work_activity).to eq(group_notification.work_activity)
        expect(activity.message).to include("has been approved")
        expect(activity.activity_type).to eq(WorkActivity::NOTIFICATION)
        expect(activity.work_id).to eq(work.id)
        expect(group_notification.user_id).to eq(user.id)
        expect(group_notification.email_sent).to eq({ "type" => "publish", "email" => user.email })
        expect(user_notification.email_sent).to eq({ "type" => "publish", "email" => work.created_by_user.email })
        expect(user_notification.user_id).to eq(work.created_by_user_id)
      end
    end
    context "when the work is withdrawn" do
      let(:to_state) { :withdrawn }
      let(:from_state) { :awaiting_approval }

      it "creates WorkActivityNotifications for each user" do
        expect do
          transition_notification.send
        end.to change(WorkActivityNotification, :count)
          .by(0).and change(WorkActivity, :count).by(1)

        activity = WorkActivity.last
        expect(activity.message).to include("withdrawn")
        expect(activity.activity_type).to eq(WorkActivity::NOTIFICATION)
        expect(activity.work_id).to eq(work.id)
      end
    end
  end
end
