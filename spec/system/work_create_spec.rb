# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Form submission for a legacy dataset", type: :system do
  let(:user) { FactoryBot.create(:princeton_submitter) }
  let!(:curator) { FactoryBot.create(:user, groups_to_admin: [Group.first]) }
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

  before do
    stub_s3
    stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.34770"))
  end
  context "happy path" do
    it "produces and saves a valid datacite record", js: true do
      sign_in user
      visit new_work_path(params: { wizard: true })
      click_on "Create New"
      expect(page).to have_content("Must provide a title")
      expect(page).to have_content("Must provide at least one creator")
      fill_in "title_main", with: title

      find("tr:last-child input[name='creators[][given_name]']").set "Samantha"
      # context "when the family name is not provided" do
      # click_on "Create New"
      # expect(page).to have_content("Must provide a family name")

      find("tr:last-child input[name='creators[][family_name]']").set "Abrams"
      click_on "Add Another Creator"
      # context "when the given name and family name is not provided" do
      # click_on "Create New"
      # expect(page).to have_content("Must provide a given name")
      # expect(page).to have_content("Must provide a family name")
      find("tr:last-child input[name='creators[][given_name]']").set "Alexis"
      find("tr:last-child input[name='creators[][family_name]']").set "Antracoli"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][given_name]']").set "Rachel"
      find("tr:last-child input[name='creators[][family_name]']").set "Appel"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][given_name]']").set "Celia"
      find("tr:last-child input[name='creators[][family_name]']").set "Caust-Ellenbogen"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][given_name]']").set "Sarah"
      find("tr:last-child input[name='creators[][family_name]']").set "Dennison"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][given_name]']").set "Sumitra"
      find("tr:last-child input[name='creators[][family_name]']").set "Duncan"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][given_name]']").set "Stefanie"
      find("tr:last-child input[name='creators[][family_name]']").set "Ramsay"
      click_on "Add me as a Creator"
      expect(find("tr:last-child input[name='creators[][given_name]']").value).to eq(user.given_name)
      expect(find("tr:last-child input[name='creators[][family_name]']").value).to eq(user.family_name)
      expect(find("tr:last-child input[name='creators[][affiliation]']").value).to eq("")
      # Separate test?
      expect(page).to have_button("Add me as a Creator", disabled: true)

      click_on "Create New"
      expect(Work.all).not_to be_empty
      work = Work.last
      expect(work.resource.creators).not_to be_empty
      # Check for the persisted creators
    end
  end

  context "with an existing and persisted Work" do
    let(:work) { FactoryBot.create(:none_work, created_by_user_id: user.id) }
    it "updates required metadata", js: true do
      sign_in user
      visit edit_work_path(work, params: { wizard: true })

      fill_in "description", with: description
      select "GNU General Public License", from: "rights_identifiers"
      click_on "Curator Controlled"
      fill_in "publication_year", with: issue_date
      click_on "Save Work"
      work.reload
      expect(work.resource.description).to eq description
    end
    context "when no description is provided" do
      let(:work) do
        FactoryBot.create(:none_work, created_by_user_id: user.id, resource: FactoryBot.build(:resource, description: nil))
      end
      it "renders a warning", js: true do
        sign_in user
        visit edit_work_path(work, params: { wizard: true })

        select "GNU General Public License", from: "rights_identifiers"
        click_on "Curator Controlled"
        fill_in "publication_year", with: issue_date
        click_on "Save Work"
        expect(page).to have_content("Must provide a description")
      end
    end
    context "when required metadata is provided" do
      let(:work) do
        # FactoryBot.create(:draft_work, created_by_user_id: user.id, resource: FactoryBot.build(:resource, description: nil))
        FactoryBot.create(:draft_work, created_by_user_id: user.id)
      end
      it "updates additional metadata", js: true do
        expect(work.resource.related_objects.count).to eq(0)
        click_on "Additional Metadata"
        expect(page).to have_content("Additional Individual Contributors")
        # click_on "Save Work"
        # context: when no description is provided
        # expect(page).to have_content("Must provide a description")
        find("tr:last-child input[name='related_objects[][related_identifier]']").set "https://related.example.com"
        click_on "Save Work"
        # click_on "Back"
        expect(page).to have_content(description)
      end
    end

    context "when there is no README attached to the Work" do
      xit "provides a form for uploading the README", js: true do
        click_on "Save Work"
        expect(page).to have_content("Please upload the README")
        expect(page).to have_button("Continue", disabled: true)
        path = Rails.root.join("spec", "fixtures", "files", "readme.txt")
        attach_file(path) do
          page.find("#patch_readme_file").click
        end
        click_on "Continue"

        # Make sure the readme is in S3 so when I hit the back button we do not error
        stub_s3 data: [FactoryBot.build(:s3_readme, work:)]

        click_on "Back"
        expect(page).to have_content("Please upload the README")
        expect(page).to have_content("README.txt was previously uploaded. You will replace it if you select a different file.")
      end
    end

    xit "allows one to specify additional metadata" do
      click_on "Continue"
      page.find(:xpath, "//input[@value='file_other']").choose
      click_on "Continue"
      click_on "Continue"
      click_on "Complete"
      expect(page).to have_content("Related Identifier Type is missing or invalid for https://related.example.com, Relationship Type is missing or invalid for https://related.example.com")

      # This test is failing
      click_on "Additional Metadata"
      find("tr:last-child select[name='related_objects[][related_identifier_type]']").find(:option, "DOI").select_option
      find("tr:last-child select[name='related_objects[][relation_type]']").find(:option, "Cites").select_option
      find("tr:last-child input[name='contributors[][given_name]']").set "Alan"
      find("tr:last-child input[name='contributors[][family_name]']").set "Turing"
      find("tr:last-child select[name='contributors[][role]']").find(:option, "Editor").select_option
      roles = find("tr:last-child select[name='contributors[][role]']").find_all("option").map(&:text)
      expect(page).to have_field(name: "funders[][funder_name]", with: "")
      expect(page).to have_field(name: "funders[][ror]", with: "")
      expect(page).to have_field(name: "funders[][award_number]", with: "")
      expect(roles).to include("Contact Person") # Individual roles included
      expect(roles).not_to include("Hosting Institution") # Organizational roles excluded
      page.save_screenshot
      click_on "Save Work"
      page.save_screenshot
      click_on "Continue"
      expect(page).to have_content("under 100MB")
      expect(page).to have_content("more than 100MB")
      click_on "Continue"
      click_on "Continue"
      expect(page).to have_content("Please take a moment to read the terms of this license")
      click_on "Complete"

      expect(page).to have_content "awaiting_approval"

      visit(user_path(user))
      # This is the blue badge on the work that should show up for a submitter
      #  when a work is started and marked completed by a submitter
      within("#unfinished_datasets span.badge.rounded-pill.bg-primary") do
        expect(page).to have_content "2"
      end

      work = Work.last
      visit(work_path(work))

      has_been_created_message = "#{title} has been created"
      within("ul.work-messages") do
        expect(page).to have_content(has_been_created_message)
        expect(page).to have_content("#{title} is ready for review")
        expect(page).to have_content(work.group.title)
      end

      click_on "Hide Messages"
      expect(page).not_to have_content(has_been_created_message)
      click_on "Show Messages"
      expect(page).to have_content(has_been_created_message)

      # Now sign is as the group moderator and see the notification on your dashboard
      sign_out user
      sign_in curator
      visit(user_path(curator))
      expect(page).to have_content curator.given_name
      # This is the blue badge on the work that should show up for a curator
      #  when a work is startend and marked completed by a submitter
      within("#unfinished_datasets span.badge.rounded-pill.bg-primary") do
        expect(page).to have_content "2"
      end
    end
  end

  context "happy path" do
    xit "produces and saves a valid datacite record", js: true do
      sign_in user
      visit new_work_path(params: { wizard: true })
      click_on "Create New"
      expect(page).to have_content("Must provide a title")
      expect(page).to have_content("Must provide at least one creator")
      fill_in "title_main", with: title

      find("tr:last-child input[name='creators[][given_name]']").set "Samantha"
      click_on "Create New"
      expect(page).to have_content("Must provide a family name")

      find("tr:last-child input[name='creators[][family_name]']").set "Abrams"
      click_on "Add Another Creator"
      click_on "Create New"
      expect(page).to have_content("Must provide a given name")
      expect(page).to have_content("Must provide a family name")
      find("tr:last-child input[name='creators[][given_name]']").set "Alexis"
      find("tr:last-child input[name='creators[][family_name]']").set "Antracoli"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][given_name]']").set "Rachel"
      find("tr:last-child input[name='creators[][family_name]']").set "Appel"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][given_name]']").set "Celia"
      find("tr:last-child input[name='creators[][family_name]']").set "Caust-Ellenbogen"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][given_name]']").set "Sarah"
      find("tr:last-child input[name='creators[][family_name]']").set "Dennison"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][given_name]']").set "Sumitra"
      find("tr:last-child input[name='creators[][family_name]']").set "Duncan"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][given_name]']").set "Stefanie"
      find("tr:last-child input[name='creators[][family_name]']").set "Ramsay"
      click_on "Add me as a Creator"
      expect(find("tr:last-child input[name='creators[][given_name]']").value).to eq(user.given_name)
      expect(find("tr:last-child input[name='creators[][family_name]']").value).to eq(user.family_name)
      expect(find("tr:last-child input[name='creators[][affiliation]']").value).to eq("")
      expect(page).to have_button("Add me as a Creator", disabled: true)

      click_on "Create New"
      work = Work.last
      expect(work.resource.related_objects.count).to eq(0)
      click_on "Additional Metadata"
      expect(page).to have_content("Additional Individual Contributors")
      click_on "Save Work"
      expect(page).to have_content("Must provide a description")
      fill_in "description", with: description
      select "GNU General Public License", from: "rights_identifiers"
      click_on "Curator Controlled"
      fill_in "publication_year", with: issue_date
      click_on "Additional Metadata"
      find("tr:last-child input[name='related_objects[][related_identifier]']").set "https://related.example.com"
      click_on "Save Work"
      click_on "Back"
      expect(page).to have_content(description)
      click_on "Save Work"
      expect(page).to have_content("Please upload the README")
      expect(page).to have_button("Continue", disabled: true)
      path = Rails.root.join("spec", "fixtures", "files", "readme.txt")
      attach_file(path) do
        page.find("#patch_readme_file").click
      end
      click_on "Continue"

      # Make sure the readme is in S3 so when I hit the back button we do not error
      stub_s3 data: [FactoryBot.build(:s3_readme, work:)]

      click_on "Back"
      expect(page).to have_content("Please upload the README")
      expect(page).to have_content("README.txt was previously uploaded. You will replace it if you select a different file.")
      click_on "Continue"
      page.find(:xpath, "//input[@value='file_other']").choose
      click_on "Continue"
      click_on "Continue"
      click_on "Complete"
      expect(page).to have_content("Related Identifier Type is missing or invalid for https://related.example.com, Relationship Type is missing or invalid for https://related.example.com")

      # This test is failing
      click_on "Additional Metadata"
      find("tr:last-child select[name='related_objects[][related_identifier_type]']").find(:option, "DOI").select_option
      find("tr:last-child select[name='related_objects[][relation_type]']").find(:option, "Cites").select_option
      find("tr:last-child input[name='contributors[][given_name]']").set "Alan"
      find("tr:last-child input[name='contributors[][family_name]']").set "Turing"
      find("tr:last-child select[name='contributors[][role]']").find(:option, "Editor").select_option
      roles = find("tr:last-child select[name='contributors[][role]']").find_all("option").map(&:text)
      expect(page).to have_field(name: "funders[][funder_name]", with: "")
      expect(page).to have_field(name: "funders[][ror]", with: "")
      expect(page).to have_field(name: "funders[][award_number]", with: "")
      expect(roles).to include("Contact Person") # Individual roles included
      expect(roles).not_to include("Hosting Institution") # Organizational roles excluded
      click_on "Save Work"
      click_on "Continue"
      expect(page).to have_content("under 100MB")
      expect(page).to have_content("more than 100MB")
      click_on "Continue"
      click_on "Continue"
      expect(page).to have_content("Please take a moment to read the terms of this license")
      click_on "Complete"

      expect(page).to have_content "awaiting_approval"

      visit(user_path(user))
      # This is the blue badge on the work that should show up for a submitter
      #  when a work is started and marked completed by a submitter
      within("#unfinished_datasets span.badge.rounded-pill.bg-primary") do
        expect(page).to have_content "2"
      end

      work = Work.last
      visit(work_path(work))

      has_been_created_message = "#{title} has been created"
      within("ul.work-messages") do
        expect(page).to have_content(has_been_created_message)
        expect(page).to have_content("#{title} is ready for review")
        expect(page).to have_content(work.group.title)
      end

      click_on "Hide Messages"
      expect(page).not_to have_content(has_been_created_message)
      click_on "Show Messages"
      expect(page).to have_content(has_been_created_message)

      # Now sign is as the group moderator and see the notification on your dashboard
      sign_out user
      sign_in curator
      visit(user_path(curator))
      expect(page).to have_content curator.given_name
      # This is the blue badge on the work that should show up for a curator
      #  when a work is startend and marked completed by a submitter
      within("#unfinished_datasets span.badge.rounded-pill.bg-primary") do
        expect(page).to have_content "2"
      end
    end
  end

  context "when there is an error minting the DOI" do
    let(:data_cite_failure) { double }
    let(:data_cite_response) { double }
    let(:data_cite_connection) { instance_double(Datacite::Client) }

    before do
      allow(data_cite_failure).to receive(:reason_phrase).and_return("test-reason-phrase")
      allow(data_cite_failure).to receive(:status).and_return("test-status")
      allow(data_cite_response).to receive(:failure).and_return(data_cite_failure)
      allow(data_cite_response).to receive(:success?).and_return(false)
      allow(data_cite_connection).to receive(:autogenerate_doi).and_return(data_cite_response)
      allow(Datacite::Client).to receive(:new).and_return(data_cite_connection)
    end

    it "flashes the error and redirects to the new submission", js: true do
      sign_in user
      visit new_work_path(params: { migrate: true })
      fill_in "title_main", with: title
      fill_in "description", with: description
      click_on "Add me as a Creator"
      click_on "Migrate"

      expect(page).to have_content "Failed to create a new Dataset: Error generating DOI"
      expect(page.current_url).to include(new_work_path(params: { migrate: true }))
    end
  end

  context "invalid readme" do
    it "prevents the user from continuing when the readme file is not valid", js: true do
      sign_in user
      visit new_work_path(params: { wizard: true })
      click_on "Create New"
      fill_in "title_main", with: title

      find("tr:last-child input[name='creators[][given_name]']").set "Samantha"
      find("tr:last-child input[name='creators[][family_name]']").set "Abrams"
      click_on "Create New"

      fill_in "description", with: description
      click_on "Save Work"

      expect(page).to have_content("Please upload the README")
      expect(page).to have_button("Continue", disabled: true)

      # Make sure we limit the file extensions a user can select
      expect(page.html.include?('accept=".txt,.md"')).to be true

      # We on purpose upload a non-read me file...
      path = Rails.root.join("spec", "fixtures", "files", "orcid.csv")
      attach_file(path) do
        page.find("#patch_readme_file").click
      end
      # ...and we expect and error message to be displayed and the button to continue to remain disabled
      expect(page).to have_content("You must select a file that includes the word README in the name")
      expect(page).to have_button("Continue", disabled: true)
    end
  end
end
