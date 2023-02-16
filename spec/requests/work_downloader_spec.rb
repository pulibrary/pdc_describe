# frozen_string_literal: true
require "rails_helper"

RSpec.describe "WorkDownloaders", type: :request do
  describe "GET /download" do
    it "Does not allow download for annonymous users" do
      get "/works/1/download?filename=abc123"
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  context "when authenticated" do
    let(:user) { FactoryBot.create :user }
    let(:work) { FactoryBot.create(:draft_work) }
    before do
      sign_in(user)
      work
    end

    describe "GET /download" do
      it "Does not allow download for any random user" do
        get "/works/#{work.id}/download?filename=abc123"
        expect(response).to redirect_to(root_path)
      end

      context "The user who created the work" do
        let(:user) { work.created_by_user }
        let(:file) { FactoryBot.build :s3_file }

        it "rediects to S3" do
          fake_s3_service = stub_s3 data: [file]
          allow(fake_s3_service).to receive(:file_url).with(file.key).and_return("https://example-bucket.s3.amazonaws.com/#{file.key}")

          get "/works/#{work.id}/download?filename=#{file.key}"
          expect(response.code).to redirect_to("https://example-bucket.s3.amazonaws.com/#{file.key}")
          expect(fake_s3_service).to have_received(:file_url).once
        end
      end
    end
  end
end
