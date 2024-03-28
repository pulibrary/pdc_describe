# frozen_string_literal: true

require "rails_helper"

RSpec.describe WorksWizardController do
  include ActiveJob::TestHelper
  before do
    stub_ark
    Group.create_defaults
    user
    stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.34770"))
    allow(ActiveStorage::PurgeJob).to receive(:new).and_call_original

    stub_request(:get, /#{Regexp.escape('https://example-bucket.s3.amazonaws.com/us_covid_20')}.*\.csv/).to_return(status: 200, body: "", headers: {})
  end

  let(:group) { Group.first }
  let(:curator) { FactoryBot.create(:user, groups_to_admin: [group]) }
  let(:resource) { FactoryBot.build :resource }
  let(:work) { FactoryBot.create(:draft_work, doi: "10.34770/123-abc") }
  let(:user) { work.created_by_user }
  let(:pppl_user) { FactoryBot.create(:pppl_submitter) }

  let(:uploaded_file) { fixture_file_upload("us_covid_2019.csv", "text/csv") }

  context "valid user login" do
    it "renders the new submission wizard' step 0" do
      sign_in user
      get :new_submission
      expect(response).to render_template("new_submission")
    end

    describe "#new_submission_save" do
      let(:params) do
        {
          "title_main" => "test dataset updated",
          "group_id" => work.group.id,
          "creators" => [{ "orcid" => "", "given_name" => "Jane", "family_name" => "Smith" }]
        }
      end

      it "renders creates the work and renders the edit wizard page when creating a new submission" do
        sign_in user
        expect { post(:new_submission_save, params:) }.to change { Work.count }.by 1
        expect(response.status).to be 302
        expect(response.location.start_with?("http://test.host/works/")).to be true
      end

      # In theory we should never get to the new submission without a title, because the javascript should prevent it
      # In reality we are occasionally having issues with the javascript failing and the button submitting anyway.
      context "no title is present" do
        let(:params_no_title) do
          {
            "group_id" => work.group.id,
            "creators" => [{ "orcid" => "", "given_name" => "Jane", "family_name" => "Smith" }]
          }
        end
        it "renders the edit page when creating a new dataset without a title" do
          sign_in user
          post(:new_submission_save, params: params_no_title)
          expect(response.status).to be 302
          # rubocop:disable Layout/LineLength
          expect(assigns[:errors]).to eq(["We apologize, the following errors were encountered: Must provide a title. Please contact the PDC Describe administrators for any assistance."])
          # rubocop:enable Layout/LineLength
          expect(response).to redirect_to(work_create_new_submission_path)
        end
      end

      context "save and stay on page" do
        let(:save_only_params) { params.merge(save_only: true) }
        it "renders the edit page when creating a new dataset with save only" do
          sign_in user
          post(:new_submission_save, params: save_only_params)
          expect(response.status).to be 200
          expect(response).to render_template(:new_submission)
        end
      end
    end

    describe "#update_wizard" do
      let(:params) do
        {
          "title_main" => "test dataset updated",
          "description" => "a new description",
          "group_id" => work.group.id,
          "commit" => "Update Dataset",
          "controller" => "works",
          "action" => "update",
          "id" => work.id.to_s,
          "wizard" => "true",
          "publisher" => "Princeton University",
          "publication_year" => "2022",
          creators: [{ "orcid" => "", "given_name" => "Jane", "family_name" => "Smith" }]
        }
      end

      it "updates the Work and redirects the client to select attachments" do
        sign_in user
        post(:update_wizard, params:)
        expect(response.status).to be 302
        expect(response.location).to eq "http://test.host/works/#{work.id}/readme-select"
        expect(ActiveStorage::PurgeJob).not_to have_received(:new)
      end

      context "save and stay on page" do
        let(:stay_params) { params.merge(save_only: true) }

        it "updates the Work and redirects the client to select attachments" do
          sign_in user
          post(:update_wizard, params: stay_params)
          expect(response.status).to be 200
          expect(response).to render_template(:edit_wizard)
        end
      end
    end

    describe "#readme_select" do
      let(:fake_readme) { instance_double Readme, file_name: "README.txt" }

      before do
        allow(Readme).to receive(:new).and_return(fake_readme)
      end

      it "renders view to upload the readme" do
        sign_in user
        get :readme_select, params: { id: work.id }
        expect(response).to render_template(:readme_select)
        expect(assigns[:readme]).to eq("README.txt")
      end
    end

    describe "#readme_uploaded" do
      let(:attach_status) { nil }
      let(:fake_readme) { instance_double Readme, attach: attach_status, "blank?": true, file_name: "abc123" }
      let(:params) do
        {
          "_method" => "patch",
          "authenticity_token" => "MbUfIQVvYoCefkOfSpzyS0EOuSuOYQG21nw8zgg2GVrvcebBYI6jy1-_3LSzbTg9uKgehxWauYS8r1yxcN1Lwg",
          "patch" => {
            "readme_file" => uploaded_file
          },
          "commit" => "Continue",
          "controller" => "works",
          "action" => "file_uploaded",
          "id" => work.id
        }
      end

      before do
        allow(Readme).to receive(:new).and_return(fake_readme)
        sign_in user
      end

      it "redirects to file-upload" do
        post(:readme_uploaded, params:)
        expect(response.status).to be 302
        expect(fake_readme).to have_received(:attach)
        expect(response.location).to eq "http://test.host/works/#{work.id}/attachment-select"
      end

      context "save and stay on page" do
        let(:save_only_params) { params.merge(save_only: true) }

        it "stays on the readme select page" do
          post :readme_uploaded, params: save_only_params
          expect(response.status).to be 200
          expect(fake_readme).to have_received(:attach)
          expect(response).to render_template(:readme_select)
        end
      end

      context "the upload encounters an error" do
        let(:attach_status) { "An error occured" }

        it "Stays on the same page" do
          post(:readme_uploaded, params:)
          expect(response).to redirect_to(work_readme_select_path(work))
          expect(controller.flash[:notice]).to eq("An error occured")
        end
      end
    end

    describe "#attachment_select" do
      it "renders view to select the kind of attachment to use" do
        sign_in user
        get :attachment_select, params: { id: work.id }
        expect(response).to render_template(:attachment_select)
      end
    end

    describe "#attachment_selected" do
      let(:attachment_type) { "file_upload" }
      let(:fake_s3_service) { stub_s3 }
      let(:params) { { id: work.id, attachment_type: } }

      before do
        fake_s3_service
        sign_in user
      end

      it "redirects to file-upload" do
        post(:attachment_selected, params:)
        expect(response.status).to be 302
        expect(response.location).to eq "http://test.host/works/#{work.id}/file-upload"
        expect(fake_s3_service).not_to have_received(:create_directory)
      end

      context "save and stay on page" do
        let(:save_only_params) { params.merge(save_only: true) }

        it "stays on the attachment select page" do
          post :attachment_selected, params: save_only_params
          expect(response.status).to be 200
          expect(response).to render_template(:attachment_select)
        end
      end

      context "when type is file_other" do
        let(:attachment_type) { "file_other" }

        it "redirects to file-other" do
          post(:attachment_selected, params:)
          expect(response.status).to be 302
          expect(response.location).to eq "http://test.host/works/#{work.id}/file-other"
          expect(fake_s3_service).to have_received(:create_directory)
        end
      end
    end

    describe "#file_upload" do
      it "renders the page to upload files directly" do
        sign_in user
        get :file_upload, params: { id: work.id }
        expect(response).to render_template(:file_upload)
      end
    end

    describe "#file_uploaded" do
      let(:params) do
        {
          "_method" => "patch",
          "authenticity_token" => "MbUfIQVvYoCefkOfSpzyS0EOuSuOYQG21nw8zgg2GVrvcebBYI6jy1-_3LSzbTg9uKgehxWauYS8r1yxcN1Lwg",
          "patch" => {
            "pre_curation_uploads" => [uploaded_file]
          },
          "commit" => "Continue",
          "controller" => "works",
          "action" => "file_uploaded",
          "id" => work.id
        }
      end

      context "with an uploaded CSV file" do
        let(:fake_s3_service) { stub_s3 }

        let(:bucket_url) do
          "https://example-bucket.s3.amazonaws.com/"
        end

        before do
          sign_in user
          fake_s3_service # make sure the s3 service is mocked here
        end

        it "upload files directly from user requests" do
          post(:file_uploaded, params:)
          perform_enqueued_jobs
          expect(response).to redirect_to(work_review_path)
          expect(fake_s3_service).to have_received(:upload_file).with(hash_including(filename: "us_covid_2019.csv"))
        end

        context "save and stay on page" do
          let(:save_only_params) { params.merge(save_only: true) }
  
          it "stays on the attachment select page" do
            post(:file_uploaded, params: save_only_params)
            perform_enqueued_jobs
            expect(response).to render_template(:file_upload)
            expect(response.status).to be 200
            expect(fake_s3_service).to have_received(:upload_file).with(hash_including(filename: "us_covid_2019.csv"))
              post :attachment_selected, params: save_only_params
          end
        end
  
        context "when files are not specified within the parameters" do
          let(:params_no_files) do
            params["patch"].delete("pre_curation_uploads")
            params
          end

          it "does not update the work" do
            post(:file_uploaded, params: params_no_files)
            perform_enqueued_jobs
            expect(response).to redirect_to(work_review_path)
            expect(fake_s3_service).not_to have_received(:upload_file)
          end
        end
      end

      context "when file uploads raise errors" do
        let(:bucket_url) do
          "https://example-bucket.s3.amazonaws.com/"
        end

        let(:persisted) do
          instance_double(Work, id: work.id, upload_snapshots: [], to_s: work.id, doi: work.doi, s3_query_service: nil)
        end

        before do
          sign_in user
          work.save

          allow(Rails.logger).to receive(:error)
          allow(Work).to receive(:find).and_return(persisted)
          allow(persisted).to receive(:changes).and_raise("Error!")

          post :file_uploaded, params:
        end

        it "does not update the work and renders an error messages" do
          # TODO: - how do we tell the user there was an error now that this in not in the page context?
          # This error that is happening seems to be just a random error so it is ok that we still capture that
          expect(response).to redirect_to(work_file_upload_path(work))
          expect(controller.flash[:notice].start_with?("Failed to attach the file uploads for the work #{work.doi}")).to be true
          expect(Rails.logger).to have_received(:error).with(/Failed to attach the file uploads for the work #{work.doi}/)
        end
      end
    end

    describe "#file_other" do
      it "renders the page to indicate instructions on files on a different location" do
        sign_in user
        get :file_other, params: { id: work.id }
        expect(response).to render_template(:file_other)
      end
    end

    describe "#review" do
      before do
        sign_in user
      end

      it "renders the review page and saves the location notes" do
        post :review, params: { id: work.id, location_notes: "my files can be found at http://aws/my/data" }
        expect(response).to render_template(:review)
        expect(Work.find(work.id).location_notes).to eq "my files can be found at http://aws/my/data"
      end

      context "save and stay on page" do
        it "stays on the file other page" do
          post :review, params: { id: work.id, location_notes: "my files can be found at http://aws/my/data", save_only: true }
          expect(response.status).to be 200
          expect(response).to render_template(:file_other)
          expect(Work.find(work.id).location_notes).to eq "my files can be found at http://aws/my/data"
        end
      end
    end

    describe "#validate" do
      before do
        stub_s3
      end

      it "saves the submission notes and renders the user dashboard" do
        sign_in user
        post :validate, params: { id: work.id, submission_notes: "I need this processed ASAP" }
        expect(response.status).to be 302
        expect(response.location).to eq "http://test.host/users/#{user.uid}"
        expect(Work.find(work.id).submission_notes).to eq "I need this processed ASAP"
      end

      context "an invalid work" do
        it "handles completion errors" do
          work.resource.description = nil
          work.save
          sign_in user
          post :validate, params: { id: work.id }
          expect(response).to redirect_to(edit_work_wizard_path(work))
          expect(response.status).to be 302
          expect(work.reload).to be_draft
          # rubocop:disable Layout/LineLength
          expect(assigns[:errors]).to eq(["We apologize, the following errors were encountered: Must provide a description. Please contact the PDC Describe administrators for any assistance."])
          # rubocop:enable Layout/LineLength
        end
      end
    end
  end
end
