# frozen_string_literal: true

require "rails_helper"

RSpec.describe WizardNewSubmissionController do
  include ActiveJob::TestHelper

  let(:user) { FactoryBot.create :princeton_submitter }
  let(:work) { FactoryBot.create :policy_work, created_by_user_id: user.id }

  before do
    stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.34770"))
    work # makes sure the work is initialized before the tests
  end

  context "valid user login" do
    before do
      sign_in user
    end

    describe "#new_submission" do
      it "renders the new submission wizard' step 0" do
        get :new_submission, params: { id: work.id }
        expect(response).to render_template("new_submission")
        work_on_page = assigns[:work]
        expect(work_on_page.id).to eq(work.id)
        expect(work_on_page.work_activity.count).to eq(1)
      end
    end

    describe "#new_submission_cancel" do
      it "Removes the work and redirects to the user's dashboard" do
        expect { get :new_submission_delete, params: { id: work.id } }.to change { Work.count }.by(-1)
        expect(response.status).to be 302
        expect(response.location).to eq "http://test.host/users/#{user.uid}"
      end
    end

    describe "#new_submission_save" do
      let(:params) do
        {
          id: work.id,
          "title_main" => "test dataset updated",
          "group_id" => work.group.id,
          "creators" => [{ "orcid" => "", "given_name" => "Jane", "family_name" => "Smith" }]
        }
      end

      it "updates the work and renders the edit wizard page when creating a new submission" do
        sign_in user
        expect { patch(:new_submission_save, params:) }.to change { WorkActivity.count }.by 2
        expect(Work.last.work_activity.count).to eq(3) # keeps the policay activity
        expect(response.status).to be 302
        expect(response.location.start_with?("http://test.host/works/")).to be true
      end

      # In theory we should never get to the new submission without a title, because the javascript should prevent it
      # In reality we are occasionally having issues with the javascript failing and the button submitting anyway.
      context "no title is present" do
        let(:params_no_title) do
          {
            id: work.id,
            "group_id" => work.group.id,
            "creators" => [{ "orcid" => "", "given_name" => "Jane", "family_name" => "Smith" }]
          }
        end
        it "renders the edit page when creating a new dataset without a title" do
          sign_in user
          patch(:new_submission_save, params: params_no_title)
          expect(response.status).to be 200
          expect(assigns[:errors]).to eq(["Must provide a title"])
          expect(response).to render_template(:new_submission)
        end
      end
    end
  end

  context "other user login" do
    let(:other_user) { FactoryBot.create :princeton_submitter }

    before do
      sign_in other_user
    end

    describe "#new_submission" do
      it "redirects to the user dashboard" do
        get :new_submission, params: { id: work.id }
        expect(response.status).to be 302
        expect(response.location).to eq "http://test.host/users/#{other_user.uid}"
        expect(flash[:notice]).to eq("You do not have permission to modify the work.")
      end
    end

    describe "#new_submission_cancel" do
      it "redirects to the user dashboard" do
        expect { get :new_submission_delete, params: { id: work.id } }.to change { Work.count }.by(0)
        expect(response.status).to be 302
        expect(response.location).to eq "http://test.host/users/#{other_user.uid}"
        expect(flash[:notice]).to eq("You do not have permission to modify the work.")
      end
    end

    describe "#new_submission_save" do
      let(:params) do
        {
          id: work.id,
          "title_main" => "test dataset updated",
          "group_id" => work.group.id,
          "creators" => [{ "orcid" => "", "given_name" => "Jane", "family_name" => "Smith" }]
        }
      end
      it "redirects to the user dashboard" do
        expect { patch(:new_submission_save, params:) }.to change { WorkActivity.count }.by 0
        expect(response.status).to be 302
        expect(response.location).to eq "http://test.host/users/#{other_user.uid}"
        expect(flash[:notice]).to eq("You do not have permission to modify the work.")
      end
    end
  end

  context "invalid user" do
    describe "#new_submission" do
      it "redirects the user" do
        get :new_submission, params: { id: work.id }
        expect(response.status).to be 302
        expect(response.location).to eq "http://test.host/sign_in"
      end
    end

    describe "#new_submission_cancel" do
      let(:work) { FactoryBot.create :policy_work }

      it "redirects the user" do
        expect { get :new_submission_delete, params: { id: work.id } }.to change { Work.count }.by(0)
        expect(response.status).to be 302
        expect(response.location).to eq "http://test.host/sign_in"
      end
    end

    describe "#new_submission_save" do
      let(:params) do
        {
          id: work.id,
          "title_main" => "test dataset updated",
          "group_id" => work.group.id,
          "creators" => [{ "orcid" => "", "given_name" => "Jane", "family_name" => "Smith" }]
        }
      end

      it "redirects the user" do
        expect { patch(:new_submission_save, params:) }.to change { WorkActivity.count }.by 0
        expect(response.status).to be 302
        expect(response.location).to eq "http://test.host/sign_in"
      end
    end
  end
end
