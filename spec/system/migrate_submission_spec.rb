# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Form submission for a legacy dataset", type: :system, mock_ezid_api: true, js: true do
  include ActiveJob::TestHelper

  let(:user) { FactoryBot.create(:research_data_moderator) }
  let(:doi) { "10.34770/123-abc" }
  let(:title) { "Sowing the Seeds for More Usable Web Archives: A Usability Study of Archive-It" }
  let(:contributors) do
    [
      "Abrams, Samantha",
      "Antracoli, Alexis",
      "Appel, Rachel",
      "Caust-Ellenbogen, Celia",
      "Dennison, Sarah",
      "Duncan, Sumitra",
      "Ramsay, Stefanie"
    ]
  end
  let(:issue_date) { 2019 }
  let(:related_publication) { "Sowing the Seeds for More Usable Web Archives: A Usability Study of Archive-It, Fall/Winter 2019, Vol. 82, No. 2." }
  let(:abstract) do
    "In 2017, seven members of the Archive-It Mid-Atlantic Users Group (AITMA) conducted a study of 14 subjects representative of their stakeholder
    populations to assess the usability of Archive-It, a web archiving subscription service of the Internet Archive. While Archive-It is the most
    widely-used tool for web archiving, little is known about how users interact with the service. This study intended to teach us what users expect
    from web archives, which exist as another form of archival material. End-user subjects executed four search tasks using the public Archive-It
    interface and the Wayback Machine to access archived information on websites from the facilitators' own harvested collections and provide feedback
    about their experiences. The tasks were designed to have straightforward pass or fail outcomes, and the facilitators took notes on the subjects'
    behavior and commentary during the sessions. Overall, participants reported mildly positive impressions of Archive-It public user interface based
    on their session. The study identified several key areas of improvement for the Archive-It service pertaining to metadata options, terminology display,
    indexing of dates, and the site's search box."
  end
  let(:description) { "Download the README.txt for a detailed description of this dataset's content." }
  let(:ark) { "http://arks.princeton.edu/ark:/88435/dsp01d791sj97j" }
  let(:group) { "Research Data" }

  context "non moderator user" do
    let(:user) { FactoryBot.create(:user) }

    it "does not allow any user to migrate a dataset" do
      sign_in user
      visit user_path(user)
      click_on(user.uid)
      expect(page).not_to have_link("Create Dataset")
    end
  end

  context "happy path" do
    before do
      stub_request(:get, "https://handle.stage.datacite.org/10.34770/123-abc").to_return(status: 200, body: "", headers: {})
      stub_s3
    end

    it "produces and saves a valid datacite record" do
      sign_in user
      visit user_path(user)
      click_on(user.uid)
      expect(page).to have_link("Create Dataset")
      click_on "Create Dataset"
      fill_in "title_main", with: title
      fill_in "creators[][given_name]", with: "Samantha"
      fill_in "creators[][family_name]", with: "Abrams"
      fill_in "description", with: description
      select "GNU General Public License", from: "rights_identifier"
      click_on "Curator Controlled"
      fill_in "doi", with: doi
      fill_in "ark", with: ark
      fill_in "publication_year", with: issue_date
      click_on "Create"
      resource = Work.last.resource
      expect(resource.creators.last.given_name).to have_content("Samantha")
      expect(resource.creators.last.family_name).to have_content("Abrams")
      expect(resource.migrated).to be_falsey
      expect(page).not_to have_button("Migrate Dataspace Files")
      click_on "Complete"
      expect(page).to have_content "awaiting_approval"
    end

    it "produces and saves a valid datacite record that is migrated" do
      sign_in user
      visit user_path(user)
      click_on(user.uid)
      expect(page).to have_link("Create Dataset")
      click_on "Create Dataset"
      fill_in "title_main", with: title
      fill_in "creators[][given_name]", with: "Samantha"
      fill_in "creators[][family_name]", with: "Abrams"
      fill_in "description", with: description
      select "GNU General Public License", from: "rights_identifier"
      click_on "Curator Controlled"
      fill_in "doi", with: doi
      fill_in "ark", with: ark
      fill_in "publication_year", with: issue_date
      click_on "Migrate"
      resource = Work.last.resource
      expect(resource.creators.last.given_name).to have_content("Samantha")
      expect(resource.creators.last.family_name).to have_content("Abrams")
      expect(resource.migrated).to be_truthy
      expect(page).to have_button("Migrate Dataspace Files")
      click_on "Complete"
      expect(page).to have_content "awaiting_approval"
    end
  end

  context "validation errors" do
    let(:work2) { FactoryBot.create :draft_work, ark: "ark:/99999/dsp01d791sj97j" }

    before do
      stub_request(:get, "https://handle.stage.datacite.org/10.34770/123-abc").to_return(status: 200, body: "", headers: {})
      stub_request(:get, "https://handle.stage.datacite.org/10.34770/123-ab").to_return(status: 404, body: "", headers: {})
      stub_s3
      work2
    end

    it "returns the user to the new page so they can recover from an error" do
      sign_in user
      visit user_path(user)
      click_on(user.uid)
      click_on "Create Dataset"
      fill_in "title_main", with: "Test title"
      fill_in "creators[][given_name]", with: "Samantha"
      fill_in "creators[][family_name]", with: "Abrams"
      fill_in "description", with: description
      select "GNU General Public License", from: "rights_identifier"
      click_on "Curator Controlled"
      fill_in "doi", with: "abc123"
      click_on "Create"
      expect(page).to have_content "Invalid DOI: does not match format"
      click_on "Curator Controlled"
      fill_in "doi", with: "10.34770/123-ab"
      click_on "Create"
      expect(page).to have_content "Invalid DOI: can not verify it's authenticity"
      click_on "Curator Controlled"
      fill_in "doi", with: work2.doi
      click_on "Create"
      expect(page).to have_content "Invalid DOI: It has already been applied to another work #{work2.id}"
      click_on "Curator Controlled"
      fill_in "ark", with: work2.ark
      click_on "Create"
      expect(page).to have_content "Invalid DOI: It has already been applied to another work #{work2.id}"
      expect(page).to have_content "Invalid ARK: It has already been applied to another work #{work2.id}"
      click_on "Curator Controlled"
      fill_in "doi", with: doi
      fill_in "ark", with: ark
      fill_in "publication_year", with: issue_date
      click_on "Required Metadata"
      fill_in "title_main", with: ""
      click_on "Create"
      expect(page).to have_content "Must provide a title"
      fill_in "title_main", with: title
      click_on "Create"
      click_on "Complete"
      expect(page).to have_content "awaiting_approval"
    end
  end

  context "DOI and Ark updates" do
    let(:curator) { FactoryBot.create(:research_data_moderator) }
    let(:datacite_stub) { stub_datacite_doi }
    let(:identifier) { @identifier } # from the mock_ezid_api
    let(:file_name) { "us_covid_2019.csv" }
    let(:uploaded_file) { fixture_file_upload(file_name, "text/csv") }
    let(:s3_client) { @s3_client }
    let(:work) { Work.last }

    before do
      datacite_stub # make sure the stub is created before we start the test

      Rails.configuration.update_ark_url = true
      Rails.configuration.datacite.user = curator

      allow(Honeybadger).to receive(:notify)

      sign_in curator

      work.save!
      work.reload

      stub_s3 data: [FactoryBot.build(:s3_file)]
      allow(Work).to receive(:find).with(work.id).and_return(work)
      allow(Work).to receive(:find).with(work.id.to_s).and_return(work)
      allow(work).to receive(:publish_precurated_files).and_return(true)

      visit work_path(work)
      click_on "Approve"
    end

    context "Approving a work with a DOI we own" do
      let(:work) { FactoryBot.create :awaiting_approval_work, doi: "#{Rails.configuration.datacite.prefix}/abc-123", ark: "ark:/88435/dsp01d791sj97j" }

      it "updates the DOI and ARK url when approved" do
        expect(datacite_stub).to have_received("update")
        expect(identifier).to have_received("target=")
        expect(identifier).to have_received("save")
      end
    end

    context "Approving a work with a DOI we own do not own, but also has an ARK" do
      let(:work) { FactoryBot.create :awaiting_approval_work, doi: "10.99999/abc-123", ark: "ark:/88435/dsp01d791sj97j" }

      it "updates the ARK url when approved" do
        expect(datacite_stub).not_to have_received("update")
        expect(Honeybadger).not_to have_received(:notify)
        expect(identifier).to have_received("target=")
        expect(identifier).to have_received("save")
      end
    end

    context "Approving a work with a DOI we own do not own, but does not have an ARK" do
      let(:work) { FactoryBot.create :awaiting_approval_work, doi: "10.99999/abc-123", ark: nil }
      it "updates the ARK url when approved" do
        expect(datacite_stub).not_to have_received("update")
        expect(identifier).not_to have_received("target=")
        expect(Honeybadger).to have_received(:notify)
      end
    end
  end

  context "Data migration" do
    let(:work) { FactoryBot.create :shakespeare_and_company_work }
    let(:s3_file) { FactoryBot.build :s3_file, filename: "10-34770/ackh-7y71/test_key" }
    let(:s3_directory) { FactoryBot.build :s3_file, filename: "10-34770/ackh-7y71/test_directory_key", size: 0 }
    let(:fake_s3_service) { stub_s3(data: [s3_file, s3_directory], prefix: "bucket/123/abc/") }
    let(:handle_body) { File.read(Rails.root.join("spec", "fixtures", "files", "dspace_handle.json")) }
    let(:bitsreams_body) { File.read(Rails.root.join("spec", "fixtures", "files", "dspace_bitstreams_response.json")) }
    let(:metadata_body) { File.read(Rails.root.join("spec", "fixtures", "files", "dspace_metadata_response.json")) }
    let(:bitsream1_body) { File.read(Rails.root.join("spec", "fixtures", "files", "bitstreams", "SCoData_combined_v1_2020-07_README.txt")) }
    let(:bitsream2_body) { File.read(Rails.root.join("spec", "fixtures", "files", "bitstreams", "SCoData_combined_v1_2020-07_datapackage.json")) }
    let(:bitsream3_body) { File.read(Rails.root.join("spec", "fixtures", "files", "bitstreams", "license.txt")) }

    before do
      stub_request(:get, "https://dataspace.example.com/rest/handle/88435/dsp01zc77st047")
        .to_return(status: 200, body: handle_body, headers: {})
      stub_request(:get, "https://dataspace.example.com/rest/items/104718/bitstreams")
        .to_return(status: 200, body: bitsreams_body, headers: {})
      stub_request(:get, "https://dataspace.example.com/rest/items/104718/metadata")
        .to_return(status: 200, body: metadata_body, headers: {})
      stub_request(:get, "https://dataspace.example.com/rest//bitstreams/145784/retrieve")
        .to_return(status: 200, body: bitsream1_body, headers: {})
      stub_request(:get, "https://dataspace.example.com/rest//bitstreams/145785/retrieve")
        .to_return(status: 200, body: bitsream2_body, headers: {})
      stub_request(:get, "https://dataspace.example.com/rest//bitstreams/145762/retrieve")
        .to_return(status: 200, body: bitsream3_body, headers: {})

      work.resource.migrated = true
      work.draft!(user)
      work.save
      fake_completion = instance_double(Seahorse::Client::Response, "successful?": true)
      allow(fake_s3_service).to receive(:copy_file).and_return(fake_completion)
    end

    it "allows the user to click migrate and the migration gets run" do
      sign_in user
      visit(work_path(work))
      expect(page).to have_content work.title
      click_on("Migrate Dataspace Files")
      start_activities = WorkActivity.activities_for_work(work.id, WorkActivity::MIGRATION_START)
      expect(start_activities.count).to eq(1)
      activity = start_activities.first
      expect(activity.activity_type).to eq(WorkActivity::MIGRATION_START)
      expect(activity.created_by_user_id).to eq(user.id)
      expect(page).to have_content("Migration for 4 files and 1 directory")
      perform_enqueued_jobs
      end_activities = WorkActivity.activities_for_work(work.id, WorkActivity::MIGRATION_COMPLETE)
      expect(end_activities.count).to eq(1)
      activity = end_activities.first
      expect(activity.activity_type).to eq(WorkActivity::MIGRATION_COMPLETE)
      expect(activity.created_by_user_id).to eq(user.id)
      visit(work_path(work))
      expect(page).to have_content("4 files and 1 directory have migrated from Dataspace.")
    end
  end
end
