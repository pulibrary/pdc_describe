# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Work state transions", type: :model do
  let(:curator_user) { FactoryBot.create :user, collections_to_admin: [work.collection] }

  {
    none_work: :draft!,
    draft_work: :complete_submission!
  }.each do |fixture, method_sym|
    context "a #{fixture}" do
      let(:work) { FactoryBot.create(fixture) }

      it "Creates work activity notifications for the curator & the creator after #{method_sym}" do
        curator_user # make sure the curator exists
        user = work.created_by_user
        expect do
          work.send(method_sym, user)
        end.to change { WorkActivity.count }.by(2)
          .and change { WorkActivityNotification.count }.by(2)
      end

      it "Creates a single work activity notification for the curator = creator after #{method_sym}" do
        work.created_by_user.add_role(:collection_admin, work.collection)
        user = work.created_by_user
        expect do
          work.send(method_sym, user)
        end.to change { WorkActivity.count }.by(2)
          .and change { WorkActivityNotification.count }.by(1)
      end
    end
  end

  context "a completed work" do
    let(:work) { FactoryBot.create(:awaiting_approval_work) }

    it "Creates a work activity notification for the curator & the user when approved" do
      allow(work).to receive(:publish)
      expect do
        work.approve!(curator_user)
      end.to change { WorkActivity.count }.by(2)
         .and change { WorkActivityNotification.count }.by(2)
    end
  end
end
