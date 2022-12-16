# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Work state transions", type: :model do
  let(:work) { FactoryBot.create(:none_work) }

  let(:curator_user) { FactoryBot.create :user, collections_to_admin: [work.collection] }

  it "Creates a work activity notification for the curator & the user when drafted" do
    pending "No notifications on draft"
    expect { work.draft!(work.created_by_user) }.to change { WorkActivityNotification.count }.by(2)
  end

  context "a draft work" do
    let(:work) { FactoryBot.create(:draft_work) }

    it "Creates a work activity notification for the curator & the user when completed" do
      pending "No notifications to user on draft"
      curator_user # make sure the curator exists
      expect do
        work.complete_submission!(work.created_by_user) 
      end.to change { WorkActivity.count }.by(2)
         .and change { WorkActivityNotification.count }.by(2)
    end
  end

  context "a completed work" do
    let(:work) { FactoryBot.create(:completed_work) }

    it "Creates a work activity notification for the curator & the user when approved" do
      pending "No notifications on draft"
      allow(work).to receive(:publish)
      expect do
        work.approve!(curator_user)
      end.to change { WorkActivity.count }.by(2)
         .and change { WorkActivityNotification.count }.by(2)
    end
  end
end
