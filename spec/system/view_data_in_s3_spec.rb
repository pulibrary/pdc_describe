# frozen_string_literal: true

require "rails_helper"

RSpec.describe "View status of data in S3", mock_ezid_api: true, js: true do
  before do
    sign_in user
  end

  describe "when a dataset has a DOI and its data is in S3", mock_s3_query_service: false do
    let(:user) { FactoryBot.create :princeton_submitter }
    let(:work) { FactoryBot.create(:shakespeare_and_company_work, created_by_user_id: user.id) }
    let(:s3_query_service_double) { instance_double(S3QueryService) }
    let(:file1) { FactoryBot.build :s3_file, filename: "#{work.doi}/#{work.id}/SCoData_combined_v1_2020-07_README.txt", work: work }
    let(:file2) { FactoryBot.build :s3_file, filename: "#{work.doi}/#{work.id}/SCoData_combined_v1_2020-07_datapackage.json", work: work }
    let(:s3_data) { [file1, file2] }

    let(:bucket_url) do
      "https://example-bucket.s3.amazonaws.com/"
    end

    it "shows data from S3 on the Show and Edit pages" do
      allow(S3QueryService).to receive(:new).and_return(s3_query_service_double)
      allow(s3_query_service_double).to receive(:data_profile).and_return({ objects: s3_data, ok: true })
      allow(s3_query_service_double).to receive(:file_count).and_return(s3_data.count)
      allow(s3_query_service_double).to receive(:client_s3_files).and_return(s3_data)
      allow(s3_query_service_double).to receive(:file_url).and_return("https://something-something")

      work.save
      work.reload
      work.state = "awaiting_approval"
      work.save

      visit work_path(work)
      expect(page).to have_content work.title
      expect(page).to have_content file1.filename
      expect(page).to have_content file2.filename

      click_on "Edit"
      expect(page).to have_content file1.filename
      expect(page).to have_content file2.filename
    end

    it "uses DataTable to display files" do
      allow(S3QueryService).to receive(:new).and_return(s3_query_service_double)
      allow(s3_query_service_double).to receive(:data_profile).and_return({ objects: s3_data, ok: true })
      allow(s3_query_service_double).to receive(:file_count).and_return(s3_data.count)
      allow(s3_query_service_double).to receive(:client_s3_files).and_return(s3_data)
      allow(s3_query_service_double).to receive(:file_url).and_return("https://something-something")

      work.save

      visit work_path(work)
      # DataTables is active
      expect(page).to have_content "Showing 1 to 2 of 2 entries"
      # and file are rendered as links pointing to the download endpoint
      expect(page.body.include?("download?filename=10.34770/pe9w-x904/1/SCoData_combined_v1_2020-07_datapackage.json"))
    end

    context "when item is approved" do
      let(:work) { FactoryBot.create(:approved_work) }
      it "shows data from S3" do
        stub_s3(data: [file1])

        visit work_path(work)

        expect(page).to have_link file1.filename, href: "https://example.data.globus.org/#{file1.filename}"
        expect(page).not_to have_button("Edit")
      end

      context "when user is a curator" do
        let(:user) { FactoryBot.create(:research_data_moderator) }
        it "shows data from S3" do
          stub_s3(data: s3_data)
          visit work_path(work)
          expect(page).to have_link file1.filename, href: "https://example.data.globus.org/#{file1.filename}"
          expect(page).to have_link file2.filename, href: "https://example.data.globus.org/#{file2.filename}"

          click_on "Edit"
          expect(page).to have_link file1.filename, href: "https://example.data.globus.org/#{file1.filename}"
          expect(page).to have_link file2.filename, href: "https://example.data.globus.org/#{file2.filename}"
        end
      end

      context "when user is a super admin user" do
        let(:user) { FactoryBot.create(:research_data_moderator) }
        it "shows data from S3" do
          stub_s3(data: s3_data)
          visit work_path(work)
          expect(page).to have_link file1.filename, href: "https://example.data.globus.org/#{file1.filename}"
          expect(page).to have_link file2.filename, href: "https://example.data.globus.org/#{file2.filename}"

          click_on "Edit"
          expect(page).to have_link file1.filename, href: "https://example.data.globus.org/#{file1.filename}"
          expect(page).to have_link file2.filename, href: "https://example.data.globus.org/#{file2.filename}"
        end
      end
    end
  end
end
