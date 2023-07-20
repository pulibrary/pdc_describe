# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Form submission for migrating dynamic-tension", type: :system, mock_ezid_api: true, js: true do
  let(:user) { FactoryBot.create(:pppl_moderator) }
  let(:title) { "A dynamic magnetic tension force as the cause of failed solar eruptions" }
  let(:description) do
    "Coronal mass ejections are solar eruptions driven by a sudden release of magnetic energy stored in the Sun's corona. In many cases, this magnetic energy is stored in long-lived, arched structures called magnetic flux ropes. When a flux rope destabilizes, it can either erupt and produce a coronal mass ejection or fail and collapse back towards the Sun. The prevailing belief is that the outcome of a given event is determined by a magnetohydrodynamic force imbalance called the torus instability. This belief is challenged, however, by observations indicating that torus-unstable flux ropes sometimes fail to erupt. This contradiction has not yet been resolved because of a lack of coronal magnetic field measurements and the limitations of idealized numerical modelling. Here we report the results of a laboratory experiment that reveal a previously unknown eruption criterion below which torus-unstable flux ropes fail to erupt. We find that such 'failed torus' events occur when the guide magnetic field (that is, the ambient field that runs toroidally along the flux rope) is strong enough to prevent the flux rope from kinking. Under these conditions, the guide field interacts with electric currents in the flux rope to produce a dynamic toroidal field tension force that halts the eruption. This magnetic tension force is missing from existing eruption models, which is why such models cannot explain or predict failed torus events."
  end
  let(:ark) { "ark:/88435/dsp01j3860933c" }
  let(:group) { "Princeton Plasma Physics Lab (PPPL)" }
  let(:publisher) { "Princeton University" }
  let(:doi) { "10.11578/1366453" }
  let(:keywords) { "laboratory plasma astrophysics, solar eruptions, coronal mass ejections, magnetohydrodynamic instabilities" }

  before do
    stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.11578"))
    stub_request(:get, "https://handle.stage.datacite.org/10.11578/1366453")
      .to_return(status: 200, body: "", headers: {})
    stub_s3
  end
  context "migrate record from dataspace" do
    it "produces and saves a valid datacite record" do
      sign_in user
      visit "/works/new"
      fill_in "title_main", with: title
      fill_in "description", with: description
      select "Creative Commons Attribution 4.0 International", from: "rights_identifiers"
      find("tr:last-child input[name='creators[][orcid]']").set "0000-0003-4539-8406"
      find("tr:last-child input[name='creators[][given_name]']").set "Clayton"
      find("tr:last-child input[name='creators[][family_name]']").set "Myers"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set "0000-0003-4996-1649"
      find("tr:last-child input[name='creators[][given_name]']").set "Maasaki"
      find("tr:last-child input[name='creators[][family_name]']").set "Yamada"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set "0000-0001-9600-9963"
      find("tr:last-child input[name='creators[][given_name]']").set "Hantao"
      find("tr:last-child input[name='creators[][family_name]']").set "Ji"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set "0000-0003-3881-1995"
      find("tr:last-child input[name='creators[][given_name]']").set "Jongsoo"
      find("tr:last-child input[name='creators[][family_name]']").set "Yoo"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set "0000-0001-6289-858X"
      find("tr:last-child input[name='creators[][given_name]']").set "William"
      find("tr:last-child input[name='creators[][family_name]']").set "Fox"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set "0000-0003-0760-6198"
      find("tr:last-child input[name='creators[][given_name]']").set "Jonathan"
      find("tr:last-child input[name='creators[][family_name]']").set "Jara-Almonte"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set ""
      find("tr:last-child input[name='creators[][given_name]']").set "Antonia"
      find("tr:last-child input[name='creators[][family_name]']").set "Savcheva"
      click_on "Add Another Creator"
      find("tr:last-child input[name='creators[][orcid]']").set ""
      find("tr:last-child input[name='creators[][given_name]']").set "Edward E"
      find("tr:last-child input[name='creators[][family_name]']").set "DeLuca"

      click_on "Additional Metadata"
      fill_in "keywords", with: keywords

      ## Funder Information
      # https://ror.org/01bj3aw27 == ROR for United States Department of Energy
      page.find(:xpath, "//table[@id='funding']//tr[1]//input[@name='funders[][ror]']").set "https://ror.org/01bj3aw27"
      page.find(:xpath, "//table[@id='funding']//tr[1]//input[@name='funders[][award_number]']").set "DE-AC02-09CH11466"

      click_on "Curator Controlled"
      fill_in "publisher", with: publisher
      fill_in "publication_year", with: 2015
      select group, from: "group_id"
      fill_in "doi", with: doi
      fill_in "ark", with: ark
      click_on "Migrate"
      expect(page).to have_button("Migrate Dataspace Files")
      expect(page).to have_content "marked as Draft"
      expect(page).to have_content "Creative Commons Attribution 4.0 International"
      click_on "Complete"
      expect(page).to have_content "awaiting_approval"
      dynamic_tension_work = Work.last
      expect(dynamic_tension_work.title).to eq title
      expect(dynamic_tension_work.ark).to eq ark

      # Check that RORs were persisted as funder names
      funders = dynamic_tension_work.resource.funders.map(&:funder_name).uniq
      expect(funders).to contain_exactly("United States Department of Energy")

      # # Ensure the datacite record produced validates against our local copy of the datacite schema.
      # # This will allow us to evolve our local datacite standards and test our records against them.
      datacite = PDCSerialization::Datacite.new_from_work(dynamic_tension_work)
      expect(datacite.valid?).to eq true

      expect(datacite.to_xml).to be_equivalent_to(File.read("spec/system/data_migration/dynamic_tension.xml"))
      export_spec_data("dynamic_tension.json", dynamic_tension_work.to_json)
    end
  end
end
