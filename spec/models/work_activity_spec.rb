# frozen_string_literal: true
require "rails_helper"

describe WorkActivity, type: :model do
  let(:user) { FactoryBot.create :user }
  let(:work) { FactoryBot.create(:draft_work) }

  describe "#notify_users" do
    let(:message) { "test message for @#{user.uid}" }
    let(:work_activity) do
      described_class.add_system_activity(work.id, message, user.id)
    end

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
end
