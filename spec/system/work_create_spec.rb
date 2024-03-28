# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Form submission for a legacy dataset", type: :system do
  let(:user) { FactoryBot.create(:princeton_submitter) }
  let(:group) { Group.first }
  let!(:curator) { FactoryBot.create(:user, groups_to_admin: [group]) }
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
    stub_ark
    stub_s3
    stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.34770"))
  end

  context "when using the wizard mode and creating a new work" do
    it "persists the required metadata and saves a valid work", js: true do
      sign_in user
      visit work_create_new_submission_path

      fill_in "title_main", with: title

      find("tr:last-child input[name='creators[][given_name]']").set "Samantha"

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
      expect(page).to have_button("Add me as a Creator", disabled: true)
      # make sure an empty creator row does not stop the form submission
      click_on "Add Another Creator"
      click_on "Next"
      expect(Work.all).not_to be_empty
      work = Work.last
      expect(work.resource.creators.length).to eq(8)
      first_creator = work.resource.creators.first
      expect(first_creator.given_name).to eq("Samantha")
      expect(first_creator.family_name).to eq("Abrams")
      last_creator = work.resource.creators.last
      expect(last_creator.given_name).to eq(user.given_name)
      expect(last_creator.family_name).to eq(user.family_name)
    end

    context "when failing to provide the title" do
      it "it renders a warning in response to form submissions", js: true do
        sign_in user
        visit work_create_new_submission_path

        fill_in "title_main", with: ""
        click_on "Next"
        expect(page).to have_content("Must provide a title")
        expect(page).to have_content("Must provide at least one creator")
      end
    end

    context "when failing to provide the given name for the creator" do
      it "renders a warning in response to form submissions", js: true do
        sign_in user
        visit work_create_new_submission_path

        fill_in "title_main", with: title

        find("tr:last-child input[name='creators[][family_name]']").set "Abrams"
        click_on "Add Another Creator"
        click_on "Next"
        expect(page).to have_content("Must provide a given name")
      end
    end

    context "when failing to provide the family name for the creator" do
      it "renders a warning in response to form submissions", js: true do
        sign_in user
        visit work_create_new_submission_path

        fill_in "title_main", with: title

        find("tr:last-child input[name='creators[][given_name]']").set "Samantha"
        click_on "Add Another Creator"
        click_on "Next"
        expect(page).to have_content("Must provide a family name")
      end
    end
  end

  context "with an existing and persisted Work" do
    let(:work) { FactoryBot.create(:new_draft_work, created_by_user_id: user.id) }
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
      let(:resource) { FactoryBot.build(:resource, description: nil) }
      let(:work) do
        FactoryBot.create(:new_draft_work, created_by_user_id: user.id, resource:)
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
      let(:resource) do
        PDCMetadata::Resource.new_from_jsonb(
          {
            "doi" => "10.34770/pe9w-x904",
            "ark" => "ark:/88435/dsp01zc77st047",
            "identifier_type" => "DOI",
            "titles" => [{ "title" => "Shakespeare and Company Project Dataset: Lending Library Members, Books, Events" }],
            "description" => "All data is related to the Shakespeare and Company bookshop and lending library opened and operated by Sylvia Beach in Paris, 1919–1962.",
            "creators" => [
              {
                "value" => "Kotin, Joshua", "name_type" => "Personal", "given_name" => "Joshua", "family_name" => "Kotin", "affiliations" => [], "sequence" => "1"
              }
            ],
            "resource_type" => "Dataset",
            "publisher" => "Princeton University",
            "publication_year" => "2020",
            "version_number" => "1",
            "rights" => { "identifier" => "CC BY" }
          }
        )
      end
      let(:work) do
        FactoryBot.create(:new_draft_work, created_by_user_id: user.id, resource:)
      end
      it "updates additional metadata", js: true do
        sign_in user
        visit edit_work_path(work, params: { wizard: true })

        expect(work.resource.related_objects.count).to eq(0)

        click_on "Additional Metadata"
        wait_for_ajax
        find("tr:last-child input[name='related_objects[][related_identifier]']").set "https://related.example.com"
        find("tr:last-child select[name='related_objects[][related_identifier_type]']").find(:option, "DOI").select_option
        find("tr:last-child select[name='related_objects[][relation_type]']").find(:option, "Cites").select_option
        wait_for_ajax
        click_on "Save Work"
        work.reload

        expect(work.resource.related_objects.count).to eq(1)
        related_object = work.resource.related_objects.first
        expect(related_object).to be_a PDCMetadata::RelatedObject
        expect(related_object.related_identifier).to eq("https://related.example.com")
        expect(related_object.related_identifier_type).to eq("DOI")
        expect(related_object.relation_type).to eq("Cites")
      end
      context "when neither the related object identifier type nor the relation type are given" do
        let(:work) do
          FactoryBot.create(:new_draft_work, created_by_user_id: user.id, resource:)
        end
        it "renders a warning", js: true do
          sign_in user
          visit edit_work_wizard_path(work)

          expect(work.resource.related_objects.count).to eq(0)

          click_on "Additional Metadata"
          wait_for_ajax
          find("tr:last-child input[name='related_objects[][related_identifier]']").set "https://related.example.com"
          wait_for_ajax
          click_on "Save Work"
          work.reload
          expect(work.resource.related_objects.count).to eq(0)
          # rubocop:disable Layout/LineLength
          expect(page).to have_content("1 error prohibited this dataset from being saved:\nRelated Objects are invalid: Related Identifier Type is missing or invalid for https://related.example.com, Relationship Type is missing or invalid for https://related.example.com")
          expect(page).not_to have_content("Uncurated Files")
          expect(page).not_to have_content("Curated Files")
          # rubocop:enable Layout/LineLength
        end
      end
    end

    context "when there is no README attached to the Work" do
      let(:work) do
        FactoryBot.create(:draft_work, created_by_user_id: user.id)
      end
      it "renders the form for uploading a README", js: true do
        sign_in user
        visit work_readme_select_path(work, params: { wizard: true })

        expect(page).to have_content("Please upload the README")
        expect(page).to have_button("Continue", disabled: true)

        path = Rails.root.join("spec", "fixtures", "files", "readme.txt")
        attach_file(path) do
          page.find("#patch_readme_file").click
        end

        click_on "Continue"
        expect(page).to have_content("New Submission")

        work.reload
        stub_s3 data: [FactoryBot.build(:s3_readme, work:)]

        readme = Readme.new(work, user)
        expect(readme.file_name).not_to be nil
        expect(readme.file_name).to eq("README.txt")
      end

      context "when a README has already been attached to a Work" do
        let(:work) do
          FactoryBot.create(:draft_work, created_by_user_id: user.id)
        end

        before do
          stub_s3 data: [FactoryBot.build(:s3_readme, work:)]
        end

        it "attempting to upload another README renders an error" do
          sign_in user
          visit work_readme_select_path(work, params: { wizard: true })

          expect(page).to have_content("Please upload the README")
          expect(page).to have_content("README.txt was previously uploaded. You will replace it if you select a different file.")
        end
      end
    end

    context "when the Work already has a README file attached" do
      let(:group) { Group.default }
      let(:work) do
        FactoryBot.create(:draft_work, created_by_user_id: user.id, group:)
      end

      before do
        stub_s3 data: [FactoryBot.build(:s3_readme, work:)]
      end

      it "allows users to upload files", js: true do
        sign_in user
        visit work_file_upload_path(work, params: { wizard: true })

        path = Rails.root.join("spec", "fixtures", "files", "us_covid_2019.csv")
        attach_file(path) do
          page.find("#patch_pre_curation_uploads").click
        end

        click_on "Continue"
        expect(page).to have_content("In furtherance of its non-profit educational mission, Princeton University")
        click_on "Complete"

        work.reload
        expect(work.awaiting_approval?).to be true
        expect(page).to have_content "awaiting_approval"

        visit(user_path(user))
        # This is the blue badge on the work that should show up for a submitter
        #  when a work is started and marked completed by a submitter
        within("#unfinished_datasets span.badge.rounded-pill.bg-primary") do
          expect(page).to have_content "1"
        end

        visit(work_path(work))

        awaiting_review_message = "#{work.title} is ready for review"
        within("ul.work-messages") do
          expect(page).to have_content(awaiting_review_message)
          expect(page).to have_content(work.group.title)
        end

        click_on "Hide Messages"
        expect(page).not_to have_content(awaiting_review_message)
        click_on "Show Messages"
        expect(page).to have_content(awaiting_review_message)
      end
    end

    context "when authenticated as the curator user" do
      let(:group) do
        Group.default
      end
      let(:curator) { FactoryBot.create(:user, groups_to_admin: [group]) }
      let(:work) do
        FactoryBot.create(:awaiting_approval_work, created_by_user_id: user.id, group:, curator:)
      end

      before do
        stub_s3 data: [FactoryBot.build(:s3_readme, work:)]
      end

      it "renders the work as awaiting approval in the user dashboard", js: true do
        curator
        work

        sign_in curator
        visit(user_path(curator))
        expect(page).to have_content curator.given_name
        # This is the blue badge on the work that should show up for a curator
        #  when a work is startend and marked completed by a submitter
        within("#unfinished_datasets") do
          expect(page).to have_content work.title
        end
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
      visit work_create_new_submission_path
      click_on "Next"
      fill_in "title_main", with: title

      find("tr:last-child input[name='creators[][given_name]']").set "Samantha"
      find("tr:last-child input[name='creators[][family_name]']").set "Abrams"
      click_on "Next"

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
