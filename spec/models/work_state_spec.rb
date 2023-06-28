# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Work state transions", type: :model do
  let(:curator_user) { FactoryBot.create :user, groups_to_admin: [work.group] }
  let(:user) { work.created_by_user }
  let(:data) { [] }

  before do
    mock_s3_query_service_class(data: data)
  end

  context "when a none work is in the draft state" do
    let(:work) { FactoryBot.create(:none_work) }

    context "when the user is an admin" do
      before do
        user.add_role(:group_admin, work.group)
      end

      it "creates work activity notifications for the curator and the creator after advancing to the draft state" do
        expect do
          work.draft!(user)
        end.to change {
          WorkActivity.count
        }.by(2).and change { WorkActivityNotification.count }.by(1)
      end
    end

    it "Creates work activity notifications for the curator and the creator after advancing to the draft state" do
      curator_user # make sure the curator exists

      expect do
        work.draft!(user)
      end.to change {
        WorkActivity.count
      }.by(2).and change { WorkActivityNotification.count }.by(2)
    end
  end

  context "when a draft work is completed" do
    let(:work) { FactoryBot.create(:draft_work) }

    context "when the user is an admin" do
      before do
        user.add_role(:group_admin, work.group)
      end

      it "creates work activity notifications for the curator and the creator after advancing to the draft state" do
        expect do
          work.complete_submission!(user)
        end.to change {
          WorkActivity.count
        }.by(2).and change { WorkActivityNotification.count }.by(1)
      end
    end

    it "Creates work activity notifications for the curator and the creator after advancing to the draft state" do
      curator_user # make sure the curator exists

      expect do
        work.complete_submission!(user)
      end.to change {
        WorkActivity.count
      }.by(2).and change { WorkActivityNotification.count }.by(2)
    end
  end

  context "a completed work" do
    let(:work) { FactoryBot.create(:awaiting_approval_work) }
    let(:data) { [FactoryBot.build(:s3_file)] }

    it "creates a work activity notification for the curator and the user when approved" do
      allow(work).to receive(:publish)

      expect do
        work.approve!(curator_user)
      end.to change {
        WorkActivity.count
      }.by(2).and change { WorkActivityNotification.count }.by(2)
    end
  end
end
