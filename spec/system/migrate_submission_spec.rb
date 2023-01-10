# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Form submission for a legacy dataset", type: :system, mock_ezid_api: true, js: true do
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
  let(:collection) { "Research Data" }

  context "happy path" do
    before do
      stub_request(:get, "https://handle.stage.datacite.org/10.34770/123-abc").to_return(status: 200, body: "", headers: {})
      stub_s3
    end

    it "produces and saves a valid datacite record" do
      # Make the screen larger so the save button is alway on screen.  This avoids random `Element is not clickable` errors
      page.driver.browser.manage.window.resize_to(2000, 2000)
      sign_in user
      visit user_path(user)
      click_on(user.uid)
      click_on "Create Dataset"
      fill_in "title_main", with: title
      fill_in "given_name_1", with: "Samantha"
      fill_in "family_name_1", with: "Abrams"
      fill_in "description", with: description
      select "GNU General Public License", from: "rights_identifier"
      click_on "Curator Controlled"
      fill_in "doi", with: doi
      fill_in "ark", with: ark
      fill_in "publication_year", with: issue_date
      click_on "Create"
      click_on "Complete"
      expect(page).to have_content "awaiting_approval"
    end
  end

  context "validation errors" do
    before do
      stub_request(:get, "https://handle.stage.datacite.org/10.34770/123-abc").to_return(status: 200, body: "", headers: {})
      stub_request(:get, "https://handle.stage.datacite.org/10.34770/123-ab").to_return(status: 404, body: "", headers: {})
      stub_s3
    end

    it "returns the user to the new page so they can recover from an error" do
      # Make the screen larger so the save button is alway on screen.  This avoids random `Element is not clickable` errors
      page.driver.browser.manage.window.resize_to(2000, 2000)
      sign_in user
      visit user_path(user)
      click_on(user.uid)
      click_on "Create Dataset"
      fill_in "given_name_1", with: "Samantha"
      fill_in "family_name_1", with: "Abrams"
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
      fill_in "doi", with: doi
      fill_in "ark", with: ark
      fill_in "publication_year", with: issue_date
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

      stub_work_s3_requests(work: work, file_name: file_name)
      work.pre_curation_uploads.attach(uploaded_file)
      work.save!
      work.reload

      visit work_path(work)
      click_on "Approve"
    end

    context "Approving a work with a DOI we own" do
      let(:work) { FactoryBot.create :awaiting_approval_work, doi: "#{Rails.configuration.datacite.prefix}/abc-123", ark: "ark:/88435/dsp01d791sj97j" }

      it "updates the DOI and ARK url when approved" do
        expect(datacite_stub).to have_received("update")
        expect(identifier).to have_received("target=")
        expect(identifier).to have_received("save!")
      end
    end

    context "Approving a work with a DOI we own do not own, but also has an ARK" do
      let(:work) { FactoryBot.create :awaiting_approval_work, doi: "10.99999/abc-123", ark: "ark:/88435/dsp01d791sj97j" }

      it "updates the ARK url when approved" do
        expect(datacite_stub).not_to have_received("update")
        expect(Honeybadger).not_to have_received(:notify)
        expect(identifier).to have_received("target=")
        expect(identifier).to have_received("save!")
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
end
