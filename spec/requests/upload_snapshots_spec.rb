# frozen_string_literal: true
require "rails_helper"

RSpec.describe "UploadSnapshots", type: :request do
  let(:work) { FactoryBot.create(:awaiting_approval_work) }
  let(:work_id) { work.id }
  let(:current_work_path) { work_path(work) }
  let(:user) { FactoryBot.create :user }
  let(:curator_user) { FactoryBot.create(:user, collections_to_admin: [work.collection]) }

  # uploads
  let(:file2) { FactoryBot.build(:s3_file, filename: "#{work.doi}/#{work.id}/us_covid_2019_2.csv", work: work, size: 2048) }
  let(:uri) { file2.url }

  let(:pre_curated_data_profile) { { objects: [file2] } }
  let(:post_curation_data_profile) { { objects: [file2] } }

  let(:fake_s3_service_pre) { stub_s3(data: [file2]) }
  let(:fake_s3_service_post) { stub_s3(data: [file2]) }

  before do
    allow(S3QueryService).to receive(:new).and_return(fake_s3_service_pre, fake_s3_service_post)
    allow(fake_s3_service_pre.client).to receive(:head_object).with(bucket: "example-post-bucket", key: work.s3_object_key).and_raise(Aws::S3::Errors::NotFound.new("blah", "error"))
    allow(fake_s3_service_post).to receive(:bucket_name).and_return("example-post-bucket")
    allow(fake_s3_service_pre).to receive(:bucket_name).and_return("example-pre-bucket")

    work.approve!(curator_user)
    work.save

    sign_in(user)
  end

  describe "UploadSnapshots#create" do
    context "given the ID of the Work and URI of the file upload as the parameters" do
      let(:params) do
        {
          work_id: work_id,
          uri: uri
        }
      end

      it "creates a new UploadSnapshot and redirects the client to the Works#show view" do
        post "/upload-snapshots", params: params
        expect(response).to redirect_to(current_work_path)
      end

      context "when an error is raised connecting to the server API" do
        before do
          allow(Rails.logger).to receive(:error)
          allow(Work).to receive(:find).and_raise(StandardError, "This is an example error.")
          post "/upload-snapshots", params: params
        end

        it "renders a message that a message was encountered" do
          expect(controller.flash["notice"]).not_to be_nil
          expect(controller.flash["notice"]).to eq("Failed to create the upload snapshot: This is an example error.")
          expect(Rails.logger).to have_received(:error).with("Failed to create the upload snapshot: This is an example error.")

          expect(response).to redirect_to(works_path)
        end
      end
    end
  end

  describe "UploadSnapshots#destroy" do
    context "given the ID of the UploadSnapshot as a parameter" do
      let(:upload_snapshot) { FactoryBot.create(:upload_snapshot, work: work) }
      let(:id) { upload_snapshot.id }

      it "deletes an existing UploadSnapshot and redirects the client to the Works#show view" do
        delete "/upload-snapshots/#{id}"
        expect(response).to redirect_to(current_work_path)
      end

      context "when an error is raised retrieving the persisted upload snapshot" do
        before do
          allow(Rails.logger).to receive(:error)
          allow(UploadSnapshot).to receive(:find).and_raise(StandardError, "This is an example error.")
          delete "/upload-snapshots/#{id}"
        end

        it "renders a message that a message was encountered" do
          expect(controller.flash["notice"]).not_to be_nil
          expect(controller.flash["notice"]).to eq("Failed to delete the upload snapshot: This is an example error.")
          expect(Rails.logger).to have_received(:error).with("Failed to delete the upload snapshot: This is an example error.")

          expect(response).to redirect_to(works_path)
        end
      end
    end
  end
end
