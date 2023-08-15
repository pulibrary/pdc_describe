# frozen_string_literal: true
require "rails_helper"

describe WorkActivityNotification, type: :model do
  let(:user) { FactoryBot.create :user }
  let(:group) { Group.default }
  let(:work) { FactoryBot.create(:work, group: group) }
  let(:work_activity) { FactoryBot.create(:work_activity, work: work) }
  let(:notification_mailer) { instance_double(NotificationMailer) }
  let(:message_delivery) { instance_double(ActionMailer::Parameterized::MessageDelivery) }

  describe ".new" do
    before do
      allow(message_delivery).to receive(:deliver_later)
      allow(notification_mailer).to receive(:build_message).and_return(message_delivery)
      allow(NotificationMailer).to receive(:with).and_return(notification_mailer)
    end

    it "enqueues an e-mail message to be delivered for the notification" do
      described_class.create(user: user, work_activity: work_activity)
      expect(message_delivery).to have_received(:deliver_later)
    end

    context "when e-mail notifications are disabled for the Group" do
      before do
        group.disable_messages_for(user: user)
      end

      it "does not enqueue an e-mail message to be delivered for the notification" do
        described_class.create(user: user, work_activity: work_activity)
        expect(message_delivery).not_to have_received(:deliver_later)
      end

      context "a messge notification" do
        let(:work_activity) { FactoryBot.create(:work_activity_message, work: work, message: "direct message to @#{user.uid}") }

        it "does enqueue an e-mail message to be delivered for the notification" do
          described_class.create(user: user, work_activity: work_activity)
          expect(message_delivery).to have_received(:deliver_later)
        end
      end

      context "a messge notification without an @" do
        let(:work_activity) { FactoryBot.create(:work_activity_message, work: work) }

        it "does not enqueue an e-mail message to be delivered for the notification" do
          described_class.create(user: user, work_activity: work_activity)
          expect(message_delivery).not_to have_received(:deliver_later)
        end
      end
    end

    context "when e-mail notifications are disabled for the user" do
      let(:user) { FactoryBot.create(:user, email_messages_enabled: false) }

      it "does not enqueue any e-mail messages" do
        described_class.create(user: user, work_activity: work_activity)
        expect(message_delivery).not_to have_received(:deliver_later)
      end

      context "a messge notification" do
        let(:work_activity) { FactoryBot.create(:work_activity_message, work: work, message: "direct message to @#{user.uid}") }

        it "does enqueue an e-mail message to be delivered for the notification" do
          described_class.create(user: user, work_activity: work_activity)
          expect(message_delivery).to have_received(:deliver_later)
        end
      end

      context "a messge notification without an @" do
        let(:work_activity) { FactoryBot.create(:work_activity_message, work: work) }

        it "does not enqueue an e-mail message to be delivered for the notification" do
          described_class.create(user: user, work_activity: work_activity)
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

      context "a messge notification" do
        let(:work_activity) { FactoryBot.create(:work_activity_message, work: work, message: "direct message to @#{user.uid}") }

        it "does enqueue an e-mail message to be delivered for the notification" do
          described_class.create(user: user, work_activity: work_activity)
          expect(message_delivery).to have_received(:deliver_later)
        end
      end

      context "a messge notification without an @" do
        let(:work_activity) { FactoryBot.create(:work_activity_message, work: work) }

        it "does enqueue an e-mail message to be delivered for the notification" do
          described_class.create(user: user, work_activity: work_activity)
          expect(message_delivery).to have_received(:deliver_later)
        end

        context "when the group is disabled" do
          before do
            group.disable_messages_for(user: user)
          end

          it "does not enqueue an e-mail message to be delivered for the notification" do
            described_class.create(user: user, work_activity: work_activity)
            expect(message_delivery).not_to have_received(:deliver_later)
          end
        end

        context "When a subcommunity is applied to the work" do
          before do
            work.resource.subcommunities = ["NTSXU"]
            work.save!
          end

          it "does enqueue an e-mail message to be delivered for the notification" do
            described_class.create(user: user, work_activity: work_activity)
            expect(message_delivery).to have_received(:deliver_later)
          end

          it "does not enqueue an e-mail message to be delivered for the notification when the subcommunity is disabled" do
            group.disable_messages_for(user: user, subcommunity: "NTSXU")
            described_class.create(user: user, work_activity: work_activity)
            expect(message_delivery).not_to have_received(:deliver_later)
          end
        end

        context "When a multiple subcommunities are applied to the work" do
          before do
            work.resource.subcommunities = ["NTSXU", "MAST-U"]
            work.save!
          end

          it "does enqueue an e-mail message to be delivered for the notification" do
            described_class.create(user: user, work_activity: work_activity)
            expect(message_delivery).to have_received(:deliver_later)
          end

          it "does not enqueue an e-mail message to be delivered for the notification when the subcommunities are disabled" do
            group.disable_messages_for(user: user, subcommunity: "NTSXU")
            group.disable_messages_for(user: user, subcommunity: "MAST-U")
            described_class.create(user: user, work_activity: work_activity)
            expect(message_delivery).not_to have_received(:deliver_later)
          end

          it "does enqueue an e-mail message to be delivered for the notification when only one subcommunity is disabled" do
            group.disable_messages_for(user: user, subcommunity: "MAST-U")
            described_class.create(user: user, work_activity: work_activity)
            expect(message_delivery).to have_received(:deliver_later)
          end
        end
      end
    end
  end
end
