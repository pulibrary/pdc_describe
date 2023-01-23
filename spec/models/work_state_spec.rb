# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Work state transions", type: :model do
  let(:curator_user) { FactoryBot.create :user, collections_to_admin: [work.collection] }

  {
    none_work: :draft!,
    draft_work: :complete_submission!,
    awaiting_approval_work: :approve!
  }.each do |fixture, method_sym|
    context "a #{fixture}" do
      let(:work) { FactoryBot.create(fixture) }

      it "Creates a work activity notification for the curator & the user after #{method_sym}" do
        curator_user # make sure the curator exists
        allow(work).to receive(:publish) # Only relevant for approve.
        expect do
          work.send(method_sym, method_sym == :approve! ? curator_user : work.created_by_user)
        end.to change { WorkActivity.count }.by(2)
          .and change { WorkActivityNotification.count }.by(2)
      end
    end
  end  
end
