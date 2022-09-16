# frozen_string_literal: true

require "rails_helper"

RSpec.describe "View status of data in S3", mock_ezid_api: true do
  before do
    sign_in user
  end

  describe "when a dataset has a DOI and its data is in S3", mock_s3_query_service: false do
    let(:user) { FactoryBot.create :princeton_submitter }
    let(:work) { FactoryBot.create(:shakespeare_and_company_work) }
    let(:s3_query_service_double) { instance_double(S3QueryService) }
    let(:file1) do
      {
        key: "SCoData_combined_v1_2020-07_README.txt",
        last_modified: Time.parse("2022-04-21T18:29:40.000Z"),
        size: 10_759,
        etag: "abc123"
      }
    end
    let(:file2) do
      {
        key: "SCoData_combined_v1_2020-07_datapackage.json",
        last_modified: Time.parse("2022-04-21T18:30:07.000Z"),
        size: 12_739,
        etag: "abc567"
      }
    end
    let(:s3_data) { [file1, file2] }

    let(:bucket_url) do
      "https://example-bucket.s3.amazonaws.com/"
    end

    it "shows data from S3 on the Show and Edit pages", js: true do
      # Account for files in S3 added outside of ActiveStorage
      allow(S3QueryService).to receive(:new).and_return(s3_query_service_double)
      allow(s3_query_service_double).to receive(:data_profile).and_return({ objects: s3_data, ok: true })
      # Account for files uploaded to S3 via ActiveStorage
      stub_request(:put, /#{bucket_url}/).to_return(status: 200)

      file = fixture_file_upload("us_covid_2019.csv", "text/csv")
      work.pre_curation_uploads.attach(file)
      work.save
      work.reload
      work.state = "accepted"
      work.save

      visit work_path(work)
      expect(page).to have_content work.title
      expect(page).to have_content "us_covid_2019.csv"

      expect(page).to have_content file1[:filename]

      expect(page).to have_content file2[:filename]

      click_on "Edit"
      expect(page).to have_content "us_covid_2019.csv"
    end
  end
end
