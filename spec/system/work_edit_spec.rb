# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Creating and updating works", type: :system, js: true do
  let(:user) { FactoryBot.create(:princeton_submitter) }

  before do
    stub_s3
    stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.34770"))
  end

  let(:contents1) { FactoryBot.build :s3_file, filename: "#{work.doi}/#{work.id}/us_covid_2019.csv", work: work }
  let(:contents2) { FactoryBot.build :s3_file, filename: "#{work.doi}/#{work.id}/us_covid_2020.csv", work: work }
  let(:contents3) { FactoryBot.build :s3_file, filename: "#{work.doi}/#{work.id}/orcid.csv", work: work }

  let(:s3_hash) { [contents1, contents2] }
  let(:s3_hash_after_delete) { [contents2] }

  context "when editing an existing draft Work with uploaded files" do
    let(:work) { FactoryBot.create(:draft_work) }
    let(:user) { work.created_by_user }

    let(:bucket_url) do
      "https://example-bucket.s3.amazonaws.com/"
    end
    let(:delete_url) { "#{bucket_url}#{work.doi}/#{work.id}/us_covid_2019.csv" }
    let(:fake_s3_service) { stub_s3 }
    before do
      allow(fake_s3_service).to receive(:client_s3_files).and_return(s3_hash)
      allow(fake_s3_service).to receive(:file_url).with(contents1.key).and_return("https://example-bucket.s3.amazonaws.com/#{contents1.key}")
      allow(fake_s3_service).to receive(:file_url).with(contents2.key).and_return("https://example-bucket.s3.amazonaws.com/#{contents2.key}")
      allow(fake_s3_service).to receive(:file_url).with(contents3.key).and_return("https://example-bucket.s3.amazonaws.com/#{contents2.key}")
      # fake_aws_client = double(Aws::S3::Client)
      # fake_s3_resp = double(Aws::S3::Types::ListObjectsV2Output)
      # fake_aws_client.stub(:list_objects_v2).and_return(fake_s3_resp)
      # fake_s3_resp.stub(:to_h).and_return(s3_hash, s3_hash_after_delete)
      # s3 = S3QueryService.new(work)
      # allow(s3).to receive(:client).and_return(fake_aws_client)
      # allow(S3QueryService).to receive(:new).and_return(s3)

      stub_request(:put, /#{bucket_url}/).to_return(status: 200)
      stub_request(:delete, /#{delete_url}/).to_return(status: 200)
      work.save

      sign_in user
      visit edit_work_path(work)
    end

    it "allows users to delete one of the uploads" do
      allow(ActiveStorage::PurgeJob).to receive(:new).and_call_original
      expect(page).to have_content "Filename"
      expect(page).to have_content "Created At"
      expect(page).to have_content "Replace Upload"
      expect(page).to have_content "Delete Upload"
      expect(page).to have_content("us_covid_2019.csv")
      expect(page).to have_content("us_covid_2020.csv")
      check("work-uploads-#{work.pre_curation_uploads_fast[0].id}-delete")
      allow(fake_s3_service).to receive(:client_s3_files).and_return(s3_hash_after_delete)
      click_on "Save Work"
      within(".files.card-body") do
        expect(page).to have_content("us_covid_2020.csv")
        expect(page).not_to have_content("us_covid_2019.csv")
      end
      expect(page).to have_content(/deleted.*us_covid_2019.csv/)
      expect(fake_s3_service).to have_received(:delete_s3_object)
    end

    it "allows users to replace one of the uploads" do
      allow(ActiveStorage::PurgeJob).to receive(:new).and_call_original
      expect(page).to have_content "Filename"
      expect(page).to have_content "Created At"
      expect(page).to have_content "Replace Upload"
      expect(page).to have_content "Delete Upload"
      within(".files.card-body") do
        expect(page).to have_content("us_covid_2019.csv")
        expect(page).to have_content("us_covid_2020.csv")
      end
      attach_file("work-deposit-uploads-#{work.pre_curation_uploads_fast.first.id}", Rails.root.join("spec", "fixtures", "files", "orcid.csv"))
      allow(fake_s3_service).to receive(:client_s3_files).and_return([contents2, contents3])
      click_on "Save Work"
      within(".files.card-body") do
        expect(page).to have_content("orcid.csv")
        expect(page).to have_content("us_covid_2020.csv")
        expect(page).not_to have_content("us_covid_2019.csv")
      end
      expect(fake_s3_service).to have_received(:delete_s3_object)
      expect(page).to have_content(/deleted.*us_covid_2019.csv/)
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
      expect(page.find("#related_identifier_type_1").value).to eq "arXiv"
      expect(page.find("#relation_type_1").value).to have_content "IsCitedBy"
    end
  end

  context "when editing funding information" do
    let(:work) { FactoryBot.create(:distinct_cytoskeletal_proteins_work) }
    let(:user) { work.created_by_user }

    it "allows the user to edit funding information" do
      sign_in user
      visit edit_work_path(work)
      click_on "Additional Metadata"
      find("input[name='funders[][funder_name]']").set "National Science Foundation"
      find("input[name='funders[][award_number]']").set "nsf-123"
      find("input[name='funders[][award_uri]']").set "http://nsg.gov/award/123"
      click_on "Add Another Funder"
      find("tr:last-child input[name='funders[][funder_name]']").set "National Sigh, Hence Foundation"
      click_on "Save Work"
      expect(page).to have_content("National Science Foundation")
      expect(page).to have_content("nsf-123")
      expect(page).to have_content("http://nsg.gov/award/123")
      expect(page).to have_content("National Sigh, Hence Foundation")

      # Test row deletion
      # (Clicking on "Edit" sends us to the multi-page wizard;
      # To just confirm that edits work, this is more direct.)
      visit edit_work_path(work)
      click_on "Additional Metadata"
      find(:xpath, "(//i[@class='bi bi-trash btn-del-row'])[1]").click
      click_on "Save Work"
      work.reload
      funders = work.resource.funders.map(&:funder_name)
      # Can't check for absence of "National Science Foundation" on the page bc it exists in the changelog
      expect(funders).to contain_exactly("National Sigh, Hence Foundation")
      expect(page).to have_content("National Sigh, Hence Foundation")

      # Test row reordering
      visit edit_work_path(work)
      click_on "Additional Metadata"
      # There should be a blank line we can immediately enter data into.
      find("tr:last-child input[name='funders[][funder_name]']").set "DOE"
      # For the second, we add a row.
      click_on "Add Another Funder"
      find("tr:last-child input[name='funders[][funder_name]']").set "NIH"

      # Funders at the top of the page, so this is sufficiently precise.
      source = page.all(".bi-arrow-down-up")[2].native
      target = page.all(".bi-arrow-down-up")[0].native
      builder = page.driver.browser.action
      builder.drag_and_drop(source, target).perform
      click_on "Save Work"
      expect(page.html.match?(/NIH.*DOE/m)).to be true # Opposite the original order of entry
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
      expect(page.first(".activity-history-title", visible: true)).to have_content "December 31, 2021 19:00"
    end
  end

  context "ORCID information" do
    # This test depends on an outside API functioning reliably.
    let(:work) { FactoryBot.create(:draft_work) }
    let(:user) { work.created_by_user }

    it "fetches information for creators" do
      sign_in user
      visit edit_work_path(work)
      fill_in "orcid_1", with: "0000-0001-8965-6820"
      expect(page.find("#given_name_1").value).to eq "Carmen"
      expect(page.find("#family_name_1").value).to eq "Valdez"
    end

    it "fetches information for individual contributors" do
      sign_in user
      visit edit_work_path(work)
      click_on "Additional Metadata"
      fill_in "contributor_orcid_1", with: "0000-0001-5443-5964"
      expect(page.find("#contributor_given_name_1").value).to eq "Melody"
      expect(page.find("#contributor_family_name_1").value).to eq "Loya"
    end
  end

  # TODO: This test passes if I add a breakpoint, but not if I run it straight through.
  #       Not sure if it's an API problem, or if I'm mis-using Capybara.
  # context "ROR information" do
  #   # This test depends on an outside API functioning reliably.
  #   let(:work) { FactoryBot.create(:draft_work) }
  #   let(:user) { work.created_by_user }

  #   it "fetches information for funders" do
  #     sign_in user
  #     visit edit_work_path(work)
  #     click_on "Additional Metadata"
  #     fill_in "funders[][ror]", with: "https://ror.org/00hx57361"
  #     expect(page.find_field("funders[][funder_name]", wait: 10).value).to eq "Princeton University"
  #   end

  #   it "fetches information for organizational contributors" do
  #     sign_in user
  #     visit edit_work_path(work)
  #     click_on "Additional Metadata"
  #     fill_in "organizational_contributors[][ror]", with: "https://ror.org/00hx57361"
  #     expect(page.find_field("organizational_contributors[][value]", wait: 10).value).to eq "Princeton University"
  #   end
  # end

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
