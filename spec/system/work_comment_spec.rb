# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Commenting on works sends emails or not", type: :system, js: true do
  let(:work) { FactoryBot.create(:draft_work, group: Group.research_data) }
  let(:user) { work.created_by_user }
  let(:user2) { FactoryBot.create(:princeton_submitter) }
  let(:message) { "@#{user2.uid} Look at this work!" }

  before do
    stub_s3
    sign_in user
    visit work_path(work)
  end

  it "Allows the user to comment and tag another user and will send an email" do
    fill_in "new-message", with: message
    expect(page).to have_content("Communication about this data submission will be through this chat feature. " \
                                 "Please use @netid to refer to each other so that we are notified that you have left a message")
    expect { click_on "Message" }
      .to change { WorkActivity.where(activity_type: WorkActivity::MESSAGE).count }.by(1)
      .and have_enqueued_job(ActionMailer::MailDeliveryJob).exactly(2).times
    expect(page).to have_content message
  end

  context "when the user has emails disabled" do
    before do
      work.group.disable_messages_for(user: user2)
    end

    it "Allows the user to comment and tag a curator and it sends an email because it is a direct message" do
      fill_in "new-message", with: message
      expect { click_on "Message" }
        .to change { WorkActivity.where(activity_type: WorkActivity::MESSAGE).count }.by(1)
        .and have_enqueued_job(ActionMailer::MailDeliveryJob).exactly(2).times
      expect(page).to have_content message
    end
  end

  context "the user is a curator" do
    let(:user2) { FactoryBot.create(:research_data_moderator) }
    let(:message) { "@#{user2.uid} Look at this work and give me feedback!" }

    it "Allows the user to comment and tag a curator but will send an email" do
      fill_in "new-message", with: message
      expect { click_on "Message" }
        .to change { WorkActivity.where(activity_type: WorkActivity::MESSAGE).count }.by(1)
        .and have_enqueued_job(ActionMailer::MailDeliveryJob).exactly(2).times
      expect(page).to have_content message
    end

    context "the message contacts a group" do
      let(:message) { "@#{work.group.code} Look at this work!" }
      it "Allows the user to comment and tag a group and it does send an email" do
        user2 # make sure the user exists to be an administrator in the group
        fill_in "new-message", with: message
        expect { click_on "Message" }
          .to change { WorkActivity.where(activity_type: WorkActivity::MESSAGE).count }.by(1)
          .and have_enqueued_job(ActionMailer::MailDeliveryJob).exactly(1).times
        expect(page).to have_content "#{work.group.title} Look at this work!"
      end
    end

    context "when the curator has emails disabled" do
      before do
        work.group.disable_messages_for(user: user2)
      end

      it "Allows the user to comment and tag a curator and it sends an email because it is a direct message" do
        fill_in "new-message", with: message
        expect { click_on "Message" }
          .to change { WorkActivity.where(activity_type: WorkActivity::MESSAGE).count }.by(1)
          .and have_enqueued_job(ActionMailer::MailDeliveryJob).exactly(2).times
        expect(page).to have_content message
      end

      context "the message contacts a group" do
        let(:message) { "@#{work.group.code} Look at this work!" }

        it "Allows the user to comment and tag a group and it does not send an email because it is not a direct message" do
          fill_in "new-message", with: message
          expect { click_on "Message" }
            .to change { WorkActivity.where(activity_type: WorkActivity::MESSAGE).count }.by(1)
            .and have_enqueued_job(ActionMailer::MailDeliveryJob).exactly(0).times
          expect(page).to have_content "#{work.group.title} Look at this work!"
        end
      end
    end
  end
end
