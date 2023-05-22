# frozen_string_literal: true
require "rails_helper"

describe WorkActivity, type: :model do
  let(:user) { FactoryBot.create :user }
  let(:work) { FactoryBot.create(:draft_work) }
  let(:message) { ["test message for @#{user.uid}"].to_json }
  let(:work_activity) do
    described_class.add_work_activity(work.id, message, user.id, activity_type: WorkActivity::SYSTEM)
  end

  describe "#notify_users" do
    before do
      work_activity
      work_activity.notify_users
    end

    it "creates WorkActivityNotifications for each user" do
      expect(WorkActivityNotification.all).not_to be_empty
      last_notification = WorkActivityNotification.last
      expect(last_notification.work_activity).to eq(work_activity)
      expect(last_notification.user).to eq(user)
    end

    context "when an invalid User is specified" do
      before do
        allow(Rails.logger).to receive(:info)
      end

      let(:message) { "test message for @invalid" }
      it "logs an error" do
        work_activity
        work_activity.notify_users

        expect(Rails.logger).to have_received(:info).with("Message #{work_activity.id} for work #{work.id} referenced an non-existing user: invalid").at_least(1).time
      end
    end
  end

  describe "#destroy" do
    it "destroys related WorkActivityNotifications" do
      work_activity.notify_users
      expect(WorkActivityNotification.where(work_activity_id: work_activity.id)).not_to be_empty
      work_activity.destroy
      expect(WorkActivityNotification.where(work_activity_id: work_activity.id)).to be_empty
    end
  end

  context "many work Activities have been sent" do
    let(:notification) { described_class.add_work_activity(work.id, message, user.id, activity_type: WorkActivity::NOTIFICATION) }
    before do
      work_activity
      notification
      work2 = FactoryBot.create(:draft_work)
      described_class.add_work_activity(work2.id, message, user.id, activity_type: WorkActivity::NOTIFICATION)
    end

    describe "#activities_for_work" do
      it "finds all the activities for the work and type" do
        expect(described_class.activities_for_work(work, [WorkActivity::SYSTEM])).to eq([work_activity])
        expect(described_class.activities_for_work(work, [WorkActivity::NOTIFICATION])).to eq([notification])
        expect(described_class.activities_for_work(work, [WorkActivity::SYSTEM, WorkActivity::NOTIFICATION])).to contain_exactly(work_activity, notification)
      end
    end

    describe "#messages_for_work" do
      it "finds all the messages for the work" do
        activity_message = described_class.add_work_activity(work.id, message, user.id, activity_type: WorkActivity::MESSAGE)
        described_class.add_work_activity(work.id, message, user.id, activity_type: WorkActivity::FILE_CHANGES)
        expect(described_class.messages_for_work(work.id)).to contain_exactly(notification, activity_message)
      end
    end

    describe "#changes_for_work" do
      it "finds all the changes for the work" do
        change_file = described_class.add_work_activity(work.id, message, user.id, activity_type: WorkActivity::FILE_CHANGES)
        changes = described_class.add_work_activity(work.id, message, user.id, activity_type: WorkActivity::CHANGES)
        migration = described_class.add_work_activity(work.id, message, user.id, activity_type: WorkActivity::MIGRATION_COMPLETE)
        described_class.add_work_activity(work.id, message, user.id, activity_type: WorkActivity::MIGRATION_START)
        described_class.add_work_activity(work.id, message, user.id, activity_type: WorkActivity::MESSAGE)
        expect(described_class.changes_for_work(work.id)).to contain_exactly(work_activity, change_file, changes, migration)
      end
    end
  end
end
