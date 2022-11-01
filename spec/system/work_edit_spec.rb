# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Creating and updating works", type: :system, js: true, mock_s3_query_service: false do
  let(:user) { FactoryBot.create(:princeton_submitter) }

  before do
    stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.34770"))
  end

  let(:contents1) do
    {
      etag: "\"008eec11c39e7038409739c0160a793a\"",
      key: "#{work.doi}/#{work.id}/us_covid_2019.csv",
      last_modified: Time.parse("2022-04-21T18:29:40.000Z"),
      size: 92,
      storage_class: "STANDARD"
    }
  end

  let(:contents2) do
    {
      etag: "\"7bd3d4339c034ebc663b990657714688\"",
      key: "#{work.doi}/#{work.id}/us_covid_2020.csv",
      last_modified: Time.parse("2022-04-21T19:29:40.000Z"),
      size: 114,
      storage_class: "STANDARD"
    }
  end

  let(:s3_hash) { { contents: [contents1, contents2] } }
  let(:s3_hash_after_delete) { { contents: [contents2] } }

  context "when editing an existing draft Work with uploaded files" do
    let(:work) { FactoryBot.create(:draft_work) }
    let(:user) { work.created_by_user }

    let(:uploaded_file1) do
      fixture_file_upload("us_covid_2019.csv", "text/csv")
    end
    let(:uploaded_file2) do
      fixture_file_upload("us_covid_2020.csv", "text/csv")
    end
    let(:uploaded_file3) do
      fixture_file_upload("orcid.csv", "text/csv")
    end
    let(:bucket_url) do
      "https://example-bucket.s3.amazonaws.com/"
    end
    let(:delete_url) { "#{bucket_url}#{work.doi}/#{work.id}/us_covid_2019.csv" }
    before do
      fake_aws_client = double(Aws::S3::Client)
      fake_s3_resp = double(Aws::S3::Types::ListObjectsV2Output)
      fake_aws_client.stub(:list_objects_v2).and_return(fake_s3_resp)
      fake_s3_resp.stub(:to_h).and_return(s3_hash, s3_hash_after_delete)
      s3 = S3QueryService.new(work)
      allow(s3).to receive(:client).and_return(fake_aws_client)
      allow(S3QueryService).to receive(:new).and_return(s3)

      stub_request(:put, /#{bucket_url}/).to_return(status: 200)
      stub_request(:delete, /#{delete_url}/).to_return(status: 200)
      work.pre_curation_uploads.attach(uploaded_file1)
      work.pre_curation_uploads.attach(uploaded_file2)
      work.save

      sign_in user
      visit work_path(work)
      visit edit_work_path(work)
    end

    it "allows users to delete one of the uploads" do
      allow(ActiveStorage::PurgeJob).to receive(:new).and_call_original
      # Make the screen larger so the save button is alway on screen.  This avoids random `Element is not clickable` errors
      page.driver.browser.manage.window.resize_to(2000, 2000)
      expect(page).to have_content "Filename"
      expect(page).to have_content "Created At"
      expect(page).to have_content "Replace Upload"
      expect(page).to have_content "Delete Upload"
      expect(page).to have_content("us_covid_2019.csv")
      expect(page).to have_content("us_covid_2020.csv")
      check("work-uploads-#{work.pre_curation_uploads[0].id}-delete")
      click_on "Save Work"
      expect(page).to have_content("us_covid_2020.csv")
      expect(page).to have_content("deleted us_covid_2019.csv")
      expect(a_request(:delete, delete_url)).to have_been_made
      expect(ActiveStorage::PurgeJob).not_to have_received(:new)
    end

    it "allows users to replace one of the uploads" do
      allow(ActiveStorage::PurgeJob).to receive(:new).and_call_original
      # Make the screen larger so the save button is alway on screen.  This avoids random `Element is not clickable` errors
      page.driver.browser.manage.window.resize_to(2000, 2000)
      expect(page).to have_content "Filename"
      expect(page).to have_content "Created At"
      expect(page).to have_content "Replace Upload"
      expect(page).to have_content "Delete Upload"
      within(".files.card-body") do
        expect(page).to have_content("us_covid_2019.csv")
        expect(page).to have_content("us_covid_2020.csv")
      end
      attach_file("work-deposit-uploads-#{work.pre_curation_uploads.first.id}", Rails.root.join("spec", "fixtures", "files", "orcid.csv"))
      click_on "Save Work"
      within(".files.card-body") do
        expect(page).to have_content("orcid.csv")
        expect(page).to have_content("us_covid_2020.csv")
        expect(page).not_to have_content("us_covid_2019.csv")
      end
      expect(page).to have_content("deleted us_covid_2019.csv")
      expect(page).to have_content("added orcid.csv")
      expect(a_request(:delete, delete_url)).to have_been_made
      expect(ActiveStorage::PurgeJob).not_to have_received(:new)
    end
  end

  context "when editing an existing draft work with related objects" do
    let(:work) { FactoryBot.create(:distinct_cytoskeletal_proteins_work) }
    let(:user) { work.created_by_user }

    it "allows the user to edit existing related objects" do
      sign_in user
      visit edit_work_path(work)
      click_on "Additional Metadata"
      expect(page.find("#related_identifier_1").value).to eq "https://www.biorxiv.org/content/10.1101/545517v1"
      expect(page.find("#related_identifier_type_1").value).to eq "ARXIV"
      expect(page.find("#relation_type_1").value).to have_content "IS_CITED_BY"
    end
  end

  context "change log" do
    let(:work) { FactoryBot.create(:distinct_cytoskeletal_proteins_work) }
    let(:user) { work.created_by_user }

    it "toggles the display of changes" do
      sign_in user
      visit edit_work_path(work)
      fill_in "title_main", with: "UPDATED" + work.resource.titles.first.title
      click_on "Save Work"
      expect(page.find(".activity-history-log-title", visible: true).tag_name).to eq "div"
      uncheck "show-change-history"
      expect(page.find(".activity-history-log-title", visible: false).tag_name).to eq "div"
    end
  end
end
