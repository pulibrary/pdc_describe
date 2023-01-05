# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Form submission for migrating flume", type: :system, mock_ezid_api: true, js: true do
  let(:user) { FactoryBot.create(:research_data_moderator) }
  let(:title) { "Data from a flume experiment of passive scalar diffusion within vegetation canopies using laser-induced fluorescence" }
  let(:description) do
    "This dataset is a sequence of laser-induced fluorescence images of a dye injected in a channel flow with canopy-like stainless steel rods simulating a vegetation canopy stand. The data is acquired close to the channel bottom at z/h=0.2, where z is the height referenced to the channel bed and h is the canopy height. The dataset provides spatial distribution of scalar concentration in a plane parallel to the channel bed. The data has been used (but the data itself has not been published or available to the public) in previous work. The references are: Ghannam, K., Poggi, D., Porporato, A., & Katul, G. (2015). The spatio-temporal statistical structure and ergodic behaviour of scalar turbulence within a rod canopy. Boundary-Layer Meteorology,157(3), 447–460. Ghannam, K, Poggi, D., Bou-Zeid, E., Katul, G. (2020). Inverse cascade evidenced by information entropy of passive scalars in submerged canopy flows. Geophysical Research Letters (accepted).

The attached readme.txt file explains the data attributes"
  end
  let(:ark) { "ark:/88435/dsp01qj72pb044" }
  let(:collection) { "Research Data" }
  let(:publisher) { "Princeton University" }
  let(:doi) { "10.34770/7hyr-rf67" }
  let(:keywords) { "vegetation canopy turbulence, flume experiments, scalar diffusion, land-atmosphere interactions" }

  before do
    page.driver.browser.manage.window.resize_to(2000, 2000)
    stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.34770"))
    stub_request(:get, "https://handle.stage.datacite.org/10.34770/7hyr-rf67")
      .to_return(status: 200, body: "", headers: {})
    stub_s3
  end
  context "migrate record from dataspace" do
    it "produces and saves a valid datacite record" do
      sign_in user
      visit "/works/new"
      fill_in "title_main", with: title
      fill_in "description", with: description
      find("#rights_identifier").find(:xpath, "option[2]").select_option
      fill_in "given_name_1", with: "Khaled"
      fill_in "family_name_1", with: "Ghannam"
      click_on "Add Another Creator"
      fill_in "given_name_2", with: "Davide"
      fill_in "family_name_2", with: "Poggi"
      click_on "Add Another Creator"
      fill_in "given_name_3", with: "Gabriel"
      fill_in "family_name_3", with: "Katul"
      click_on "Add Another Creator"
      fill_in "given_name_4", with: "Elie"
      fill_in "family_name_4", with: "Bou-Zeid"
      click_on "v-pills-additional-tab"
      fill_in "keywords", with: keywords
      click_on "v-pills-curator-controlled-tab"
      fill_in "publisher", with: publisher
      fill_in "publication_year", with: 2020
      fill_in "doi", with: doi
      fill_in "ark", with: ark
      find("#collection_id").find(:xpath, "option[1]").select_option
      click_on "Create"
      expect(page).to have_content "marked as draft"
      flume_work = Work.last
      expect(flume_work.title).to eq title

      # Ensure the datacite record produced validates against our local copy of the datacite schema.
      # This will allow us to evolve our local datacite standards and test our records against them.
      datacite = PDCSerialization::Datacite.new_from_work(flume_work)
      expect(datacite.valid?).to eq true

      export_spec_data("flume.json", flume_work.to_json)
    end
  end
end
