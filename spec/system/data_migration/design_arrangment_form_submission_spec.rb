# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Form submission for migrating design-arrangment", type: :system, mock_ezid_api: true, js: true do
  let(:user) { FactoryBot.create(:pppl_moderator) }
  let(:title) { "Design of an arrangement of cubic magnets for a quasi-axisymmetric stellarator experiment" }
  let(:description) do
    "The usage of permanent magnets to shape the confining field of a stellarator has the potential to reduce or eliminate the need for non-planar coils. As a proof-of-concept for this idea, we have developed a procedure for designing an array of cubic permanent magnets that works in tandem with a set of toroidal-field coils to confine a stellarator plasma. All of the magnets in the design are constrained to have identical geometry and one of three polarization types in order to simplify fabrication while still producing sufficient field accuracy. We present some of the key steps leading to the design, including the geometric arrangement of the magnets around the device, the procedure for optimizing the polarizations according to three allowable magnet types, and the choice of magnet types to be used. We apply these methods to design an array of rare-Earth permanent magnets that can be paired with a set of planar toroidal-field coils to confine a quasi-axisymmetric plasma with a toroidal magnetic field strength of about 0.5 T on axis.

Consult the file README.txt for a more detailed description of the contents."
  end
  let(:ark) { "ark:/88435/dsp01x059cb547" }
  let(:group) { "Princeton Plasma Physics Lab (PPPL)" }
  let(:publisher) { "Princeton University" }
  let(:doi) { "10.11578/1888258" }
  let(:keywords) { "" }
  let(:relation_type) { "IsCitedBy" }

  before do
    stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.11578"))
    stub_request(:get, "https://handle.stage.datacite.org/10.11578/1888258")
      .to_return(status: 200, body: "", headers: {})
    stub_s3
  end
  context "migrate record from dataspace" do
    it "produces and saves a valid datacite record" do
      sign_in user
      visit "/works/new"
      fill_in "title_main", with: title
      fill_in "description", with: description
      select "Creative Commons Attribution 4.0 International", from: "rights_identifier"
      find("tr:last-child input[name='creators[][orcid]']").set "0000-0002-1104-4434"
      find("tr:last-child input[name='creators[][given_name]']").set "Kenneth"
      find("tr:last-child input[name='creators[][family_name]']").set "Hammond"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set "0000-0003-2337-3232"
      find("tr:last-child input[name='creators[][given_name]']").set "Caoxiang"
      find("tr:last-child input[name='creators[][family_name]']").set "Zhu"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set "0000-0001-9857-451X"
      find("tr:last-child input[name='creators[][given_name]']").set "Keith"
      find("tr:last-child input[name='creators[][family_name]']").set "Corrigan"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set "0000-0001-5679-3124"
      find("tr:last-child input[name='creators[][given_name]']").set "David"
      find("tr:last-child input[name='creators[][family_name]']").set "Gates"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set ""
      find("tr:last-child input[name='creators[][given_name]']").set "Robert"
      find("tr:last-child input[name='creators[][family_name]']").set "Lown"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set ""
      find("tr:last-child input[name='creators[][given_name]']").set "Robert"
      find("tr:last-child input[name='creators[][family_name]']").set "Mercurio"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set "0000-0002-6536-5399"
      find("tr:last-child input[name='creators[][given_name]']").set "Tony"
      find("tr:last-child input[name='creators[][family_name]']").set "Qian"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set "0000-0001-7525-0539"
      find("tr:last-child input[name='creators[][given_name]']").set "Michael"
      find("tr:last-child input[name='creators[][family_name]']").set "Zarnstorff"

      click_on "Additional Metadata"
      fill_in "keywords", with: keywords

      ## Funder Information
      # https://ror.org/01bj3aw27 == ROR for United States Department of Energy
      page.find(:xpath, "//table[@id='funding']//tr[1]//input[@name='funders[][ror]']").set "https://ror.org/01bj3aw27"
      page.find(:xpath, "//table[@id='funding']//tr[1]//input[@name='funders[][award_number]']").set "DE-AC02-09CH11466"

      # Related Objects
      find("tr:last-child input[name='related_objects[][related_identifier]']").set "https://doi.org/10.1088/1741-4326/ac906e"
      find("tr:last-child select[name='related_objects[][related_identifier_type]']").find(:option, "DOI").select_option
      find("tr:last-child select[name='related_objects[][relation_type]']").find(:option, relation_type).select_option
      click_on "Curator Controlled"
      fill_in "publisher", with: publisher
      fill_in "publication_year", with: 2022
      select group, from: "group_id"
      fill_in "doi", with: doi
      fill_in "ark", with: ark
      click_on "Migrate"
      expect(page).to have_button("Migrate Dataspace Files")
      expect(page).to have_content "marked as Draft"
      expect(page).to have_content "Creative Commons Attribution 4.0 International"
      click_on "Complete"
      expect(page).to have_content "awaiting_approval"
      design_arrangment_work = Work.last
      expect(design_arrangment_work.title).to eq title
      expect(design_arrangment_work.ark).to eq ark

      # Check that RORs were persisted as funder names
      funders = design_arrangment_work.resource.funders.map(&:funder_name).uniq
      expect(funders).to contain_exactly("United States Department of Energy")

      # # Ensure the datacite record produced validates against our local copy of the datacite schema.
      # # This will allow us to evolve our local datacite standards and test our records against them.
      datacite = PDCSerialization::Datacite.new_from_work(design_arrangment_work)
      expect(datacite.valid?).to eq true
      expect(datacite.to_xml).to be_equivalent_to(File.read("spec/system/data_migration/design_arrangment.xml"))
      export_spec_data("design_arrangment.json", design_arrangment_work.to_json)
    end
  end
end
