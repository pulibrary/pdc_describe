# frozen_string_literal: true
require "rails_helper"

describe WorkActivityNotification, type: :model do
  let(:user) { FactoryBot.create :user }
  let(:group) { Group.default }
  let(:work) { FactoryBot.create(:work, group:) }
  let(:work_activity) { FactoryBot.create(:work_activity, work:) }
  let(:notification_mailer) { instance_double(NotificationMailer) }
  let(:message_delivery) { instance_double(ActionMailer::Parameterized::MessageDelivery) }
  let(:reject_delivery) { instance_double(ActionMailer::Parameterized::MessageDelivery) }

  describe ".new" do
    before do
      allow(message_delivery).to receive(:deliver_later)
      allow(notification_mailer).to receive(:build_message).and_return(message_delivery)
      allow(notification_mailer).to receive(:reject_message).and_return(reject_delivery)
      allow(NotificationMailer).to receive(:with).and_return(notification_mailer)
    end

    it "enqueues an e-mail message to be delivered for the notification" do
      described_class.create(user:, work_activity:)
      expect(message_delivery).to have_received(:deliver_later)
    end

    context "when the notification is for a Draft submission" do
      let(:work) { FactoryBot.create(:draft_work, group:) }
      let(:new_delivery) { instance_double(ActionMailer::Parameterized::MessageDelivery) }

      before do
        allow(notification_mailer).to receive(:new_submission_message).and_return(new_delivery)
        allow(new_delivery).to receive(:deliver_later)
      end

      it "enqueues an e-mail the news submission message to be delivered for the notification" do
        described_class.create(user:, work_activity:)
        expect(message_delivery).not_to have_received(:deliver_later)
        expect(new_delivery).to have_received(:deliver_later)
      end

      context "when the notification is a user message" do
        let(:work_activity) { FactoryBot.create(:work_activity_message, work:, message: "new submission created") }

        it "enqueues an e-mail message to be delivered for the notification" do
          described_class.create(user:, work_activity:)
          expect(message_delivery).to have_received(:deliver_later)
          expect(new_delivery).not_to have_received(:deliver_later)
        end
      end
    end

    context "when the notification is for a awaiting approval submission" do
      let(:work) do
        work = FactoryBot.create(:awaiting_approval_work, group:)
        UserWork.create(user_id: user.id, work_id: work.id, state: "draft")
        UserWork.create(user_id: user.id, work_id: work.id, state: "awaiting_approval")
        work
      end
      let(:await_delivery) { instance_double(ActionMailer::Parameterized::MessageDelivery) }

      before do
        allow(notification_mailer).to receive(:review_message).and_return(await_delivery)
        allow(await_delivery).to receive(:deliver_later)
      end

      it "enqueues an e-mail the news submission message to be delivered for the notification" do
        described_class.create(user:, work_activity:)
        expect(message_delivery).not_to have_received(:deliver_later)
        expect(await_delivery).to have_received(:deliver_later)
      end

      context "when the notification is a user message" do
        let(:work_activity) { FactoryBot.create(:work_activity_message, work:, message: "new submission created") }

        it "enqueues an e-mail message to be delivered for the notification" do
          described_class.create(user:, work_activity:)
          expect(message_delivery).to have_received(:deliver_later)
          expect(await_delivery).not_to have_received(:deliver_later)
        end
      end
    end

    context "when the notification is for a rejected submission" do
      let(:work) do
        work = FactoryBot.create(:draft_work, group:)
        UserWork.create(user_id: user.id, work_id: work.id, state: "draft")
        UserWork.create(user_id: user.id, work_id: work.id, state: "awaiting_approval")
        UserWork.create(user_id: user.id, work_id: work.id, state: "draft")
        work
      end
      let(:reject_delivery) { instance_double(ActionMailer::Parameterized::MessageDelivery) }

      before do
        allow(notification_mailer).to receive(:reject_message).and_return(reject_delivery)
        allow(reject_delivery).to receive(:deliver_later)
      end

      it "enqueues an e-mail the news submission message to be delivered for the notification" do
        described_class.create(user:, work_activity:)
        expect(message_delivery).not_to have_received(:deliver_later)
        expect(reject_delivery).to have_received(:deliver_later)
      end

      context "when the notification is a user message" do
        let(:work_activity) { FactoryBot.create(:work_activity_message, work:, message: "new submission created") }

        it "enqueues an e-mail message to be delivered for the notification" do
          described_class.create(user:, work_activity:)
          expect(message_delivery).to have_received(:deliver_later)
          expect(reject_delivery).not_to have_received(:deliver_later)
        end
      end
    end

    context "when the notification is for an approved submission" do
      let(:work) do
        work = FactoryBot.create(:draft_work, group:)
        work.state = "awaiting_approval"
        work.save!
        WorkActivity.add_work_activity(work.id, "marked as #{work.state.to_s.titleize}", user.id, activity_type: WorkActivity::SYSTEM)
        work.state = "approved"
        work.save!
        WorkActivity.add_work_activity(work.id, "marked as #{work.state.to_s.titleize}", user.id, activity_type: WorkActivity::SYSTEM)
        work
      end
      let(:approve_delivery) { instance_double(ActionMailer::Parameterized::MessageDelivery) }

      before do
        pending "there is no separate approval message yet"
        allow(notification_mailer).to receive(:approve_message).and_return(approve_delivery)
        allow(approve_delivery).to receive(:deliver_later)
      end

      it "enqueues an e-mail the news submission message to be delivered for the notification" do
        described_class.create(user:, work_activity:)
        expect(message_delivery).not_to have_received(:deliver_later)
        expect(approve_delivery).to have_received(:deliver_later)
      end

      context "when the notification is a user message" do
        let(:work_activity) { FactoryBot.create(:work_activity_message, work:, message: "new submission created") }

        it "enqueues an e-mail message to be delivered for the notification" do
          described_class.create(user:, work_activity:)
          expect(message_delivery).to have_received(:deliver_later)
          expect(approve_delivery).not_to have_received(:deliver_later)
        end
      end
    end

    context "when e-mail notifications are disabled for the Group" do
      before do
        group.disable_messages_for(user:)
      end

      it "does not enqueue an e-mail message to be delivered for the notification" do
        described_class.create(user:, work_activity:)
        expect(message_delivery).not_to have_received(:deliver_later)
      end

      context "a message notification" do
        let(:work_activity) { FactoryBot.create(:work_activity_message, work:, message: "direct message to @#{user.uid}") }

        it "does enqueue an e-mail message to be delivered for the notification" do
          described_class.create(user:, work_activity:)
          expect(message_delivery).to have_received(:deliver_later)
        end
      end

      context "a message notification without an @" do
        let(:work_activity) { FactoryBot.create(:work_activity_message, work:) }

        it "does not enqueue an e-mail message to be delivered for the notification" do
          described_class.create(user:, work_activity:)
          expect(message_delivery).not_to have_received(:deliver_later)
        end
      end
    end

    context "when e-mail notifications are disabled for the user" do
      let(:user) { FactoryBot.create(:user, email_messages_enabled: false) }

      it "does not enqueue any e-mail messages" do
        described_class.create(user:, work_activity:)
        expect(message_delivery).not_to have_received(:deliver_later)
      end

      context "a message notification" do
        let(:work_activity) { FactoryBot.create(:work_activity_message, work:, message: "direct message to @#{user.uid}") }

        it "does enqueue an e-mail message to be delivered for the notification" do
          described_class.create(user:, work_activity:)
          expect(message_delivery).to have_received(:deliver_later)
        end
      end

      context "a message notification without an @" do
        let(:work_activity) { FactoryBot.create(:work_activity_message, work:) }

        it "does not enqueue an e-mail message to be delivered for the notification" do
          described_class.create(user:, work_activity:)
          expect(message_delivery).not_to have_received(:deliver_later)
        end
      end
    end

    context "A PPPL Submission" do
      let(:group) { Group.plasma_laboratory }
      let(:super_admin) { FactoryBot.create :super_admin_user }

      before do
        group.add_submitter(super_admin, user)
      end

      context "a message notification" do
        let(:work_activity) { FactoryBot.create(:work_activity_message, work:, message: "direct message to @#{user.uid}") }

        it "does enqueue an e-mail message to be delivered for the notification" do
          described_class.create(user:, work_activity:)
          expect(message_delivery).to have_received(:deliver_later)
        end
      end

      context "a message notification without an @" do
        let(:work_activity) { FactoryBot.create(:work_activity_message, work:) }

        it "does enqueue an e-mail message to be delivered for the notification" do
          described_class.create(user:, work_activity:)
          expect(message_delivery).to have_received(:deliver_later)
        end

        context "when the group is disabled" do
          before do
            group.disable_messages_for(user:)
          end

          it "does not enqueue an e-mail message to be delivered for the notification" do
            described_class.create(user:, work_activity:)
            expect(message_delivery).not_to have_received(:deliver_later)
          end
        end

        context "When a subcommunity is applied to the work" do
          before do
            work.resource.subcommunities = ["NTSXU"]
            work.save!
          end

          it "does enqueue an e-mail message to be delivered for the notification" do
            described_class.create(user:, work_activity:)
            expect(message_delivery).to have_received(:deliver_later)
          end

          it "does not enqueue an e-mail message to be delivered for the notification when the subcommunity is disabled" do
            group.disable_messages_for(user:, subcommunity: "NTSXU")
            described_class.create(user:, work_activity:)
            expect(message_delivery).not_to have_received(:deliver_later)
          end
        end

        context "When a multiple subcommunities are applied to the work" do
          before do
            work.resource.subcommunities = ["NTSXU", "MAST-U"]
            work.save!
          end

          it "does enqueue an e-mail message to be delivered for the notification" do
            described_class.create(user:, work_activity:)
            expect(message_delivery).to have_received(:deliver_later)
          end

          it "does not enqueue an e-mail message to be delivered for the notification when the subcommunities are disabled" do
            group.disable_messages_for(user:, subcommunity: "NTSXU")
            group.disable_messages_for(user:, subcommunity: "MAST-U")
            described_class.create(user:, work_activity:)
            expect(message_delivery).not_to have_received(:deliver_later)
          end

          it "does enqueue an e-mail message to be delivered for the notification when only one subcommunity is disabled" do
            group.disable_messages_for(user:, subcommunity: "MAST-U")
            described_class.create(user:, work_activity:)
            expect(message_delivery).to have_received(:deliver_later)
          end
        end
      end
    end
  end
end
