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
  let(:collection) { "Princeton Plasma Physics Laboratory" }
  let(:publisher) { "Princeton University" }
  let(:doi) { "10.11578/1888258" }
  let(:keywords) { "" }

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
      fill_in "orcid_1", with: "0000-0002-1104-4434"
      fill_in "given_name_1", with: "Kenneth"
      fill_in "family_name_1", with: "Hammond"
      click_on "Add Another Creator"
      fill_in "orcid_2", with: "0000-0003-2337-3232"
      fill_in "given_name_2", with: "Caoxiang"
      fill_in "family_name_2", with: "Zhu"
      click_on "Add Another Creator"
      fill_in "orcid_3", with: ""
      fill_in "given_name_3", with: "Keith"
      fill_in "family_name_3", with: "Korrigan"
      click_on "Add Another Creator"
      fill_in "orcid_4", with: "0000-0001-5679-3124"
      fill_in "given_name_4", with: "David"
      fill_in "family_name_4", with: "Gates"
      click_on "Add Another Creator"
      fill_in "orcid_5", with: ""
      fill_in "given_name_5", with: "Robert"
      fill_in "family_name_5", with: "Lown"
      click_on "Add Another Creator"
      fill_in "orcid_6", with: ""
      fill_in "given_name_6", with: "Robert"
      fill_in "family_name_6", with: "Mercurio"
      click_on "Add Another Creator"
      fill_in "orcid_7", with: ""
      fill_in "given_name_7", with: "Tony"
      fill_in "family_name_7", with: "Qian"
      click_on "Add Another Creator"
      fill_in "orcid_8", with: "0000-0001-7525-0539"
      fill_in "given_name_8", with: "Michael"
      fill_in "family_name_8", with: "Zarnstorff"

      click_on "Additional Metadata"
      fill_in "keywords", with: keywords

      ## Funder Information
      # https://ror.org/01bj3aw27 == ROR for United States Department of Energy
      page.find(:xpath, "//table[@id='funding']//tr[1]//input[@name='funders[][ror]']").set "https://ror.org/01bj3aw27"
      page.find(:xpath, "//table[@id='funding']//tr[1]//input[@name='funders[][award_number]']").set "DE-AC02-09CH11466"

      click_on "Curator Controlled"
      fill_in "publisher", with: publisher
      fill_in "publication_year", with: 2022
      select collection, from: "collection_id"
      fill_in "doi", with: doi
      fill_in "ark", with: ark
      click_on "Create"
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
