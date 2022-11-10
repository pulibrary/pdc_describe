# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Form submission for a legacy dataset", type: :system do
  let(:user) { FactoryBot.create(:princeton_submitter) }
  let!(:curator) { FactoryBot.create(:user, collections_to_admin: [Collection.first]) }
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

  before do
    stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.34770"))
    # Make the screen larger so the save button is alway on screen. This avoids random `Element is not clickable` errors
    page.driver.browser.manage.window.resize_to(2000, 2000)
  end
  context "happy path" do
    it "produces and saves a valid datacite record", js: true do
      sign_in user
      visit new_work_path(params: { wizard: true })
      fill_in "title_main", with: title
      expect(find("#related_object_count", visible: false).value).to eq("1")

      fill_in "given_name_1", with: "Samantha"
      fill_in "family_name_1", with: "Abrams"
      click_on "Add Another Creator"
      fill_in "given_name_2", with: "Alexis"
      fill_in "family_name_2", with: "Antracoli"
      click_on "Add Another Creator"
      fill_in "given_name_3", with: "Rachel"
      fill_in "family_name_3", with: "Appel"
      click_on "Add Another Creator"
      fill_in "given_name_4", with: "Celia"
      fill_in "family_name_4", with: "Caust-Ellenbogen"
      click_on "Add Another Creator"
      fill_in "given_name_5", with: "Sarah"
      fill_in "family_name_5", with: "Dennison"
      click_on "Add Another Creator"
      fill_in "given_name_6", with: "Sumitra"
      fill_in "family_name_6", with: "Duncan"
      click_on "Add Another Creator"
      fill_in "given_name_7", with: "Stefanie"
      fill_in "family_name_7", with: "Ramsay"
      click_on "Create New"
      work = Work.last
      expect(work.resource.related_objects.count).to eq(0)
      expect(find("#related_object_count", visible: false).value).to eq("1")
      fill_in "description", with: description
      find("#rights_identifier").find(:xpath, "option[2]").select_option
      click_on "Curator Controlled"
      fill_in "publication_year", with: issue_date
      click_on "Save Work"
      page.find(:xpath, "//input[@value='file_other']").choose
      click_on "Continue"
      click_on "Continue"
      click_on "Complete"

      expect(page).to have_content "awaiting_approval"

      # Now sign is as the collection curator and see the notification on your dashboard
      sign_out user
      sign_in curator
      visit(user_path(curator))
      expect(page).to have_content curator.display_name
      # This is the blue badge on the work that should show up for a curator
      #  when a work is marked completed by a submitter
      within("#unfinished_datasets span.badge.rounded-pill.bg-primary") do
        expect(page).to have_content "1"
      end
    end
  end
end
