# frozen_string_literal: true

require "rails_helper"

RSpec.describe WorksWizardSubmissionCompleteController do
  include ActiveJob::TestHelper

  let(:user) { FactoryBot.create :princeton_submitter }
  let(:work) { FactoryBot.create :draft_work, created_by_user_id: user.id }

  context "valid user login" do
    before do
      sign_in user
    end

    describe "#show" do
      it "show the user the work completion" do
        get(:show, params: { id: work.id })
        expect(response.status).to be 200
        expect(response).to render_template(:show)
        expect(assigns(:email)).to eq("prds@princeton.edu")
      end

      context "a pppl work" do
        let(:work) { FactoryBot.create :pppl_work }

        it "show the user the work completion with the pppl email" do
          get(:show, params: { id: work.id })
          expect(response.status).to be 200
          expect(response).to render_template(:show)
          expect(assigns(:email)).to eq("publications@pppl.gov")
        end
      end
    end
  end

  context "invalid user" do
    describe "#show" do
      it "redirects the user" do
        get(:show, params: { id: work.id })
        expect(response.status).to be 302
      end
    end
  end
end
