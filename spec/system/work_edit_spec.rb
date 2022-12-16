# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Creating and updating works", type: :system, js: true, mock_s3_query_service: false do
  let(:user) { FactoryBot.create(:princeton_submitter) }

  before do
    stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.34770"))
    page.driver.browser.manage.window.resize_to(2000, 2000)
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

  context "when editing funding information" do
    let(:work) { FactoryBot.create(:distinct_cytoskeletal_proteins_work) }
    let(:user) { work.created_by_user }

    it "allows the user to edit funding information" do
      sign_in user
      visit edit_work_path(work)
      click_on "Additional Metadata"
      fill_in "funders[][funder_name]", with: "National Science Foundation"
      fill_in "funders[][award_number]", with: "nsf-123"
      fill_in "funders[][award_uri]", with: "http://nsg.gov/award/123"
      click_on "Save Work"
      expect(page).to have_content("National Science Foundation")
      expect(page).to have_content("nsf-123")
      expect(page).to have_content("http://nsg.gov/award/123")
    end
  end

  context "change log" do
    let(:work) { FactoryBot.create(:distinct_cytoskeletal_proteins_work) }
    let(:user) { work.created_by_user }

    before do
      now = Time.utc(2022)
      allow(Time).to receive(:now) { now }
    end

    it "displays changes" do
      sign_in user
      visit edit_work_path(work)
      fill_in "title_main", with: "UPDATED" + work.resource.titles.first.title
      click_on "Save Work"
      # This depends on the timezone configured in application.rb:
      expect(page.first(".activity-history-log-title", visible: true)).to have_content "December 31, 2021 19:00"
    end
  end

  context "ORCID information" do
    let(:work) { FactoryBot.create(:draft_work) }
    let(:user) { work.created_by_user }

    it "fetches information for creators" do
      sign_in user
      visit edit_work_path(work)
      fill_in "orcid_1", with: "0000-0001-8965-6820"
      expect(page.find("#given_name_1").value).to eq "Carmen"
      expect(page.find("#family_name_1").value).to eq "Valdez"
    end

    it "fetches information for contributors" do
      sign_in user
      visit edit_work_path(work)
      click_on "Additional Metadata"
      fill_in "contributor_orcid_1", with: "0000-0001-5443-5964"
      expect(page.find("#contributor_given_name_1").value).to eq "Melody"
      expect(page.find("#contributor_family_name_1").value).to eq "Loya"
    end
  end

  context "as a user without curator privileges" do
    let(:work) { FactoryBot.create(:distinct_cytoskeletal_proteins_work) }
    let(:user) { work.created_by_user }

    it "renders the curator controlled metadata as read-only" do
      sign_in user
      visit edit_work_path(work)
      click_on "Curator Controlled"

      publisher_element = page.find("#publisher")
      expect(publisher_element.tag_name).to eq("input")
      expect(publisher_element["readonly"]).to eq("true")

      publication_year_element = page.find("#publication_year")
      expect(publication_year_element.tag_name).to eq("input")
      expect(publication_year_element["readonly"]).to eq("true")

      doi_element = page.find("#doi")
      expect(doi_element.tag_name).to eq("input")
      expect(doi_element["readonly"]).to eq("true")

      ark_element = page.find("#ark")
      expect(ark_element.tag_name).to eq("input")
      expect(ark_element["readonly"]).to eq("true")

      resource_type_element = page.find("#resource_type")
      expect(resource_type_element.tag_name).to eq("input")
      expect(resource_type_element["readonly"]).to eq("true")

      resource_type_general_element = page.find("#resource_type_general")
      expect(resource_type_general_element.tag_name).to eq("select")
      expect(resource_type_general_element["disabled"]).to eq("true")

      version_number_element = page.find("#version_number")
      expect(version_number_element.tag_name).to eq("select")
      expect(version_number_element["disabled"]).to eq("true")

      collection_id_element = page.find("#collection_id")
      expect(collection_id_element.tag_name).to eq("select")
      expect(collection_id_element["disabled"]).to eq("true")

      collection_tags_element = page.find("#collection_tags")
      expect(collection_tags_element.tag_name).to eq("input")
      expect(collection_tags_element["readonly"]).to eq("true")

      expect(page.all("input[type=text][readonly]").count).to eq(page.all("input[type=text]").count) # all inputs on curator controlled metadata should be readonly

      expect(page.all("select[disabled]").count).to eq(page.all("select").count) # all selects inputs on curator controlled metadata should be disabled
    end
  end
end
