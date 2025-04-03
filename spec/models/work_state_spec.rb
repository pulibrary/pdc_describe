# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Work state transions", type: :model do
  let(:curator_user) { FactoryBot.create :user, groups_to_admin: [work.group] }
  let(:message_delivery) { instance_double(ActionMailer::Parameterized::MessageDelivery) }
  before do
    stub_s3 data: [FactoryBot.build(:s3_readme), FactoryBot.build(:s3_file)]
  end

  {
    none_work: :draft!,
    draft_work: :complete_submission!
  }.each do |fixture, method_sym|
    [true, false].each do |creator_is_admin|
      context "a #{fixture} and creator #{creator_is_admin ? 'is' : 'not'} admin" do
        let(:work) { FactoryBot.create(fixture) }
        it "Creates work activity notifications for the curator & the creator after #{method_sym}" do
          user = work.created_by_user
          if creator_is_admin
            user.add_role(:group_admin, work.group)
          else
            curator_user # make sure the curator exists
          end
          expect do
            work.send(method_sym, user)
          end.to change { WorkActivity.count }.by(2)
                                              .and change { WorkActivityNotification.count }.by(creator_is_admin ? 1 : 2)
        end
      end
    end
  end

  context "a new work" do
    let(:work) { FactoryBot.create(:none_work) }

    it "Creates a work activity notification for the curator & the user when approved" do
      allow(work).to receive(:publish)
      stub_s3 data: [FactoryBot.build(:s3_readme), FactoryBot.build(:s3_file)]
      expect do
        work.draft!(curator_user)
      end.to change { WorkActivity.count }.by(2)
         .and change { WorkActivityNotification.count }.by(2)
    end

    it "Enqueues an email for the curator & user containing a review message" do
      allow(work).to receive(:publish)
      stub_s3 data: [FactoryBot.build(:s3_readme), FactoryBot.build(:s3_file)]
      work.draft!(curator_user)
      expect WorkActivityNotification.last.work_activity.message.include?("created")
    end
  end

  context "a completed work" do
    let(:work) { FactoryBot.create(:awaiting_approval_work) }

    it "Creates a work activity notification for the curator & the user when approved" do
      allow(work).to receive(:publish)
      stub_s3 data: [FactoryBot.build(:s3_readme), FactoryBot.build(:s3_file)]
      expect do
        work.approve!(curator_user)
      end.to change { WorkActivity.count }.by(2)
         .and change { WorkActivityNotification.count }.by(2)
    end

    it "Enqueues an email for the curator & user containing a review message" do
      allow(work).to receive(:publish)
      stub_s3 data: [FactoryBot.build(:s3_readme), FactoryBot.build(:s3_file)]
      work.approve!(curator_user)
      expect WorkActivityNotification.last.work_activity.message.include?("ready for review")
    end
  end

  context "a rejected work" do
    let(:work) { FactoryBot.create(:awaiting_approval_work) }

    it "Creates a work activity notification for the curator & the user when approved" do
      allow(work).to receive(:publish)
      stub_s3 data: [FactoryBot.build(:s3_readme), FactoryBot.build(:s3_file)]
      expect do
        work.revert_to_draft!(curator_user)
      end.to change { WorkActivity.count }.by(2)
         .and change { WorkActivityNotification.count }.by(2)
    end

    it "Enqueues an email for the curator & user containing a rejection message" do
      allow(work).to receive(:publish)
      stub_s3 data: [FactoryBot.build(:s3_readme), FactoryBot.build(:s3_file)]
      work.revert_to_draft!(curator_user)
      expect WorkActivityNotification.last.work_activity.message.include?("returned the following submission to you for revision")
    end
  end
end
