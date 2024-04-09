# frozen_string_literal: true

require "rails_helper"

RSpec.describe WizardPolicyController do
  include ActiveJob::TestHelper

  let(:user) { FactoryBot.create :princeton_submitter }

  context "valid user login" do
    before do
      sign_in user
    end

    describe "#show" do
      it "show the user the policy agreement for" do
        get(:show)
        expect(response.status).to be 200
        expect(response).to render_template(:show)
      end
    end

    describe "#update" do
      let(:params) { { "agreement" => "1" } }

      it "creates a work with an activity" do
        sign_in user
        expect { post(:update, params:) }.to change { Work.count }.by(1)
        expect(response.status).to be 302
        work = Work.last
        expect(response).to redirect_to(work_create_new_submission_path(work))

        expect(work.state).to eq("none")
        expect(work.work_activity.count).to eq(1)
      end

      context "agreement is missing" do
        let(:params) { {} }

        it "redirects to the dashboard" do
          sign_in user
          post(:update, params:)
          expect(response.status).to be 302
        end
      end
    end
  end

  context "invalid user" do
    describe "#show" do
      it "redirects the user" do
        get(:show)
        expect(response.status).to be 302
      end
    end

    describe "#update" do
      let(:params) { { "agreement" => "1" } }

      it "redirects the user" do
        post(:update, params:)
        expect(response.status).to be 302
      end
    end
  end
end
