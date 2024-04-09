# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Creating and updating works", type: :system, js: true do
  let(:user) { FactoryBot.create(:princeton_submitter) }

  before do
    stub_s3
    stub_ark
    stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.34770"))
  end

  let(:contents1) { FactoryBot.build :s3_file, filename: "#{work.doi}/#{work.id}/us_covid_2019.csv", work: }
  let(:contents2) { FactoryBot.build :s3_file, filename: "#{work.doi}/#{work.id}/us_covid_2020.csv", work: }
  let(:contents3) { FactoryBot.build :s3_file, filename: "#{work.doi}/#{work.id}/orcid.csv", work: }

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

      # Ensure that the S3 API confirms the file already exists
      stub_request(:get, /#{bucket_url}/).to_return(status: 200)
      stub_request(:put, /#{bucket_url}/).to_return(status: 200)
      stub_request(:delete, /#{delete_url}/).to_return(status: 200)
      work.save

      sign_in user
      visit edit_work_path(work)
    end

    it "allows users to delete one of the uploads" do
      allow(ActiveStorage::PurgeJob).to receive(:new).and_call_original
      allow(fake_s3_service).to receive(:client_s3_files).and_return([contents1, contents2], [contents2])

      expect(page).to have_content "Filename"
      expect(page).to have_content "Last Modified"
      expect(page).to have_content "Size"
      expect(page).to have_content("us_covid_2019.csv")
      expect(page).to have_content("us_covid_2020.csv")

      click_on "delete-file-#{contents1.safe_id}"
      click_on "Save Work"

      expect(fake_s3_service).to have_received(:delete_s3_object)
      within(".files.card-body") do
        expect(page).to have_content("us_covid_2020.csv")
        expect(page).not_to have_content("us_covid_2019.csv")
      end
    end

    it "allows users to replace one of the uploads" do
      allow(ActiveStorage::PurgeJob).to receive(:new).and_call_original
      expect(page).to have_content "Filename"
      expect(page).to have_content "Last Modified"
      expect(page).to have_content "Size"
      within(".files.card-body") do
        expect(page).to have_content("us_covid_2019.csv")
        expect(page).to have_content("us_covid_2020.csv")
      end

      # Delete one file...
      click_on "delete-file-#{contents1.safe_id}"

      # ...and add another
      Rack::Test::UploadedFile.new(File.open(Rails.root.join("spec", "fixtures", "files", "orcid.csv")))
      allow(fake_s3_service).to receive(:client_s3_files).and_return([contents2, contents3])

      click_on "Save Work"
      within(".files.card-body") do
        expect(page).to have_content("orcid.csv")
        expect(page).to have_content("us_covid_2020.csv")
        expect(page).not_to have_content("us_covid_2019.csv")
      end
      expect(fake_s3_service).to have_received(:delete_s3_object)
    end
  end

  context "when editing an existing draft work with related objects" do
    let(:work) { FactoryBot.create(:distinct_cytoskeletal_proteins_work) }
    let(:user) { work.created_by_user }

    it "allows the user to edit existing related objects" do
      sign_in user
      visit edit_work_path(work)
      click_on "Additional Metadata"

      expect(page.find("tr:first-child input[name='related_objects[][related_identifier]']").value).to eq "https://www.biorxiv.org/content/10.1101/545517v1"
      expect(page.find("tr:first-child select[name='related_objects[][related_identifier_type]']").value).to eq "arXiv"
      expect(page.find("tr:first-child select[name='related_objects[][relation_type]']").value).to have_content "IsCitedBy"
      expect(page.find("tr:last-child input[name='related_objects[][related_identifier]']").value).to eq "https://doi.org/10.7554/eLife.52482"
      expect(page.find("tr:last-child select[name='related_objects[][related_identifier_type]']").value).to eq "DOI"
      expect(page.find("tr:last-child select[name='related_objects[][relation_type]']").value).to have_content "IsCitedBy"
      click_on "Add Another Related Object"
      expect(page.html.match?(/545517v1.*52482/m)).to be true
      source = page.find_all("#related-objects-table .bi-arrow-down-up")[0].native
      target = page.find_all("#related-objects-table .bi-arrow-down-up")[1].native
      builder = page.driver.browser.action
      builder.drag_and_drop(source, target).perform
      expect(page.html.match?(/52482.*545517v1/m)).to be true
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
      expect(page).to have_content("Funding Reference")
      find(:xpath, "(//table[@id='funding']//i[@class='bi bi-trash btn-del-row'])[1]").click
      click_on "Save Work"
      work.reload
      funders = work.resource.funders.map(&:funder_name)
      # Can't check for absence of "National Science Foundation" on the page bc it exists in the changelog
      expect(funders).to include("National Sigh, Hence Foundation")
      expect(page).to have_content("National Sigh, Hence Foundation")

      # Test row reordering
      visit edit_work_path(work)
      click_on "Additional Metadata"
      expect(page).to have_content("Funding Reference")
      # TODO: Why is this breaking and should I use this format for Adding Creators
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

  context "for PRDS works" do
    let(:work) { FactoryBot.create(:distinct_cytoskeletal_proteins_work) }
    let(:user) { work.created_by_user }

    it "allows user to select a community (but not subcommunities)" do
      sign_in user
      visit edit_work_path(work)
      click_on "Additional Metadata"
      select "Department of Geosciences", from: "communities"
      expect(page).to_not have_content("Subcommunities")
      click_on "Save Work"
      expect(page).to have_content("Department of Geosciences")
    end
  end

  context "for PPPL works" do
    let(:work) { FactoryBot.create(:tokamak_work_awaiting_approval) }
    let(:user) { work.created_by_user }

    it "allows user to select a subcommunity" do
      sign_in user
      visit edit_work_path(work)
      click_on "Additional Metadata"
      select "Spherical Torus", from: "subcommunities"
      click_on "Save Work"
      expect(page).to have_content("Spherical Torus")
    end
    it "allows user to select one of the new subcommunities" do
      sign_in user
      visit edit_work_path(work)
      click_on "Additional Metadata"
      select "Tokamak Experimental Sciences", from: "subcommunities"
      click_on "Save Work"
      expect(page).to have_content("Tokamak Experimental Sciences")
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
      fill_in "creators[][orcid]", with: "0000-0001-8965-6820"
      expect(find("tr:last-child input[name='creators[][given_name]']").value).to eq "Carmen"
      expect(find("tr:last-child input[name='creators[][family_name]']").value).to eq "Valdez"
    end

    it "fetches information for individual contributors" do
      sign_in user
      visit edit_work_path(work)
      click_on "Additional Metadata"
      fill_in "contributors[][orcid]", with: "0000-0001-5443-5964"
      expect(page.find("tr:last-child input[name='contributors[][given_name]']").value).to eq "Melody"
      expect(page.find("tr:last-child input[name='contributors[][family_name]']").value).to eq "Loya"
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

  context "as a user without group admin privileges" do
    let(:work) { FactoryBot.create(:distinct_cytoskeletal_proteins_work, state:) }
    let(:user) { work.created_by_user }

    before do
      sign_in user
      visit edit_work_path(work)
    end

    context "when the Work has not yet been approved" do
      let(:state) { :draft }

      it "renders the curator controlled metadata as read-only" do
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

        group_id_element = page.find("#group_id")
        expect(group_id_element.tag_name).to eq("select")
        expect(group_id_element["disabled"]).to eq("true")

        collection_tags_element = page.find("#collection_tags")
        expect(collection_tags_element.tag_name).to eq("input")
        expect(collection_tags_element["readonly"]).to eq("true")

        expect(page.all("input[type=text][readonly]").count).to eq(page.all("input[type=text]").count) # all inputs on curator controlled metadata should be readonly

        # The +1 in here is to account for the control for file list page size that DataTables adds to the file list
        expect(page.all("select[disabled]").count + 1).to eq(page.all("select").count) # all selects inputs on curator controlled metadata should be disabled
      end

      it "properly renders a warning in response to form submissions if contributor role is not filled out", js: true do
        click_on "Additional Metadata"
        find("tr:last-child input[name='contributors[][given_name]']").set "Sally"
        find("tr:last-child input[name='contributors[][family_name]']").set "Smith"
        click_on "Save Work"
        expect(page).to have_content("Must provide a role")
        find("tr:last-child select[name='contributors[][role]']").select "Contact Person"
        # make sure an empty contributor row does not stop the form submission
        click_on "Add Another Individual Contributor"
        click_on "Save Work"
        expect(page).to have_content("Work was successfully updated.")
        click_on "Edit"
        click_on "Additional Metadata"
        expect(find("tr:last-child select[name='contributors[][role]']").value).to eq("CONTACT_PERSON")
      end
    end

    context "when the Work has been approved" do
      let(:state) { :approved }

      it "renders an error message on the edit page" do
        expect(page).to have_content("This work has been approved. Edits are no longer available.")
      end
    end
  end

  context "as a user with group admin privileges" do
    let(:work) { FactoryBot.create(:distinct_cytoskeletal_proteins_work) }
    let(:user) { FactoryBot.create :research_data_moderator }

    it "renders the curator controlled metadata as read-only" do
      sign_in user
      visit edit_work_path(work)
      click_on "Curator Controlled"

      fill_in "publisher", with: "New Publisher"
      fill_in "publication_year", with: "1996"
      fill_in "doi", with: "10.34770/123"
      fill_in "ark", with: "ark:/11111/abc12345678901"
      fill_in "resource_type", with: "Something"
      fill_in "collection_tags", with: "tag1, tag2"
      click_on "Save"

      work.reload
      expect(work.resource.publisher).to eq("New Publisher")
      expect(work.resource.publication_year).to eq("1996")
      expect(work.doi).to eq("10.34770/123")
      expect(work.ark).to eq("ark:/11111/abc12345678901")
      expect(work.resource.resource_type).to eq("Something")
      expect(work.resource.collection_tags).to eq(["tag1", "tag2"])
    end
  end

  context "when the Work has been approved" do
    context "as a user with super admin privileges" do
      let(:work) { FactoryBot.create(:distinct_cytoskeletal_proteins_work, state: :approved) }
      let(:user) { FactoryBot.create :super_admin_user }

      before do
        sign_in user
        visit edit_work_path(work)
      end

      it "renders the DOI as read-only" do
        # disabled: true and readonly: true fail to find the proper HTML element through Capybara
        expect(page).to have_field("doi", visible: false)
      end

      it "renders the DOI in the curator controlled metadata as read-only" do
        click_on "Curator Controlled"

        doi_element = page.find("#doi")
        expect(doi_element.tag_name).to eq("input")
        expect(doi_element["readonly"]).to eq("true")
      end
    end
  end

  context "when the Work has not been approved" do
    context "as a user with super admin privileges" do
      let(:work) { FactoryBot.create(:distinct_cytoskeletal_proteins_work, state: :draft) }
      let(:user) { FactoryBot.create :super_admin_user }

      before do
        sign_in user
        visit edit_work_path(work)
      end

      it "renders the DOI as read-only" do
        # disabled: true and readonly: true fail to find the proper HTML element through Capybara
        doi_element = page.find("#doi_text")
        expect(doi_element).not_to be nil
        expect(doi_element.tag_name).to eq("p")
      end
    end
  end
end
