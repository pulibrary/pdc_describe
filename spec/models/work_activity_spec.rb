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

    context "when a curator group is specified" do
      let(:group) { Group.research_data }
      let(:message) { "test message for @#{group.code}" }
      it "create WorkActivityNotifications for each curator " do
        FactoryBot.create :research_data_moderator
        FactoryBot.create :research_data_moderator
        FactoryBot.create :research_data_moderator
        work_activity
        expect { work_activity.notify_users }.to change { WorkActivityNotification.count }.by group.administrators.count
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
        embargo = described_class.add_work_activity(work.id, message, user.id, activity_type: WorkActivity::EMBARGO)
        described_class.add_work_activity(work.id, message, user.id, activity_type: WorkActivity::MIGRATION_START)
        described_class.add_work_activity(work.id, message, user.id, activity_type: WorkActivity::MESSAGE)
        expect(described_class.changes_for_work(work.id)).to contain_exactly(work_activity, change_file, changes, migration, embargo)
      end
    end
  end

  context "backdated activities" do
    it "renders backdated on back dated activities" do
      described_class.add_work_activity(work.id, message, user.id, activity_type: WorkActivity::NOTIFICATION, created_at: "2023-08-14")
      renderd_html = described_class.activities_for_work(work, [WorkActivity::NOTIFICATION]).first.to_html
      expect(renderd_html.include?("backdated")).to be true
    end

    it "does not render backdated activities by default" do
      described_class.add_work_activity(work.id, message, user.id, activity_type: WorkActivity::NOTIFICATION)
      renderd_html = described_class.activities_for_work(work, [WorkActivity::NOTIFICATION]).first.to_html
      expect(renderd_html.include?("backdated")).to be false
    end
  end

  describe "#to_html" do
    let(:work1) { FactoryBot.create(:draft_work, group: Group.research_data) }
    let(:work2) { FactoryBot.create(:draft_work, group: Group.plasma_laboratory) }
    let(:work_compare) { WorkCompareService.new(work1, work2) }

    before do
      work1.log_changes(work_compare, user.id)
    end

    it "renders the changes for works when group membership is updated" do
      changes = WorkActivity.changes_for_work(work1.id)
      expect(changes).not_to be_empty
      work_activity = changes.first
      rendered_html = work_activity.to_html
      # rubocop:disable Layout/LineLength
      expect(rendered_html).to include("<summary class='show-changes'>Group</summary>Princeton <del>Research</del><ins>Plasma</ins> <del>Data</del><ins>Physics</ins> <del>Service</del><ins>Lab</ins> (<del>PRDS</del><ins>PPPL</ins>)</details>")
      # rubocop:enable Layout/LineLength
    end
  end

  describe "embargo activity" do
    let(:work) { FactoryBot.create(:draft_work, group: Group.research_data) }
    it "show as the system" do
      activity = WorkActivity.add_work_activity(work.id, "1 file was moved to the ...", nil, activity_type: WorkActivity::EMBARGO)
      expect(activity.to_html).to include("by the system")
    end
  end
end
