# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Commenting on works sends emails or not", type: :system, js: true do
  let(:work) { FactoryBot.create(:draft_work) }
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
    expect { click_on "Message" }
      .to change { WorkActivity.where(activity_type: WorkActivity::MESSAGE).count }.by(1)
      .and have_enqueued_job(ActionMailer::MailDeliveryJob).exactly(1).times
    expect(page).to have_content message
  end

  context "when the user has emails disabled" do
    before do
      user2.disable_messages_from(group: work.group)
    end

    it "Allows the user to comment and tag a curator and it sends an email becuase it is a direct message" do
      fill_in "new-message", with: message
      expect { click_on "Message" }
        .to change { WorkActivity.where(activity_type: WorkActivity::MESSAGE).count }.by(1)
        .and have_enqueued_job(ActionMailer::MailDeliveryJob).exactly(1).times
      expect(page).to have_content message
    end
  end

  context "the user is a curator" do
    let(:user2) { FactoryBot.create(:research_data_moderator) }
    let(:message) { "@#{user2.uid} Look at this work and give me feedback!" }

    it "Allows the user to comment and tag a curator but will not send an email" do
      fill_in "new-message", with: message
      expect { click_on "Message" }
        .to change { WorkActivity.where(activity_type: WorkActivity::MESSAGE).count }.by(1)
        .and have_enqueued_job(ActionMailer::MailDeliveryJob).exactly(1).times
      expect(page).to have_content message
    end

    context "when the curator has emails disabled" do
      before do
        user2.disable_messages_from(group: work.group)
      end

      it "Allows the user to comment and tag a curator and it sends an email becuase it is a direct message" do
        fill_in "new-message", with: message
        expect { click_on "Message" }
          .to change { WorkActivity.where(activity_type: WorkActivity::MESSAGE).count }.by(1)
          .and have_enqueued_job(ActionMailer::MailDeliveryJob).exactly(1).times
        expect(page).to have_content message
      end
    end
  end
end
