# frozen_string_literal: true
require "rails_helper"

describe WorkActivityNotification, type: :model do
  let(:user) { FactoryBot.create :user }
  let(:collection) { Group.default }
  let(:work) { FactoryBot.create(:work, group: collection) }
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

    context "when e-mail notifications are disabled for the Collection" do
      before do
        user.disable_messages_from(group: collection)
      end

      it "does not enqueue an e-mail message to be delivered for the notification" do
        described_class.create(user: user, work_activity: work_activity)
        expect(message_delivery).not_to have_received(:deliver_later)
      end
    end

    context "when e-mail notifications are disabled for the user" do
      let(:user) { FactoryBot.create(:user, email_messages_enabled: false) }

      it "does not enqueue any e-mail messages" do
        described_class.create(user: user, work_activity: work_activity)
        expect(message_delivery).not_to have_received(:deliver_later)
      end
    end
  end
end
