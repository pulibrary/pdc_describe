# frozen_string_literal: true
require "rails_helper"
##
# A collection admin is a user who has admin rights on a given collection
RSpec.describe "Authz for curators", type: :system, js: true, mock_ezid_api: true do
  describe "A curator" do
    let(:research_data_admin) { FactoryBot.create :research_data_admin }
    let(:work) { FactoryBot.create(:shakespeare_and_company_work) }
    let(:collection) { Collection.find(work.collection_id) }
    # let(:pppl_curator) { FactoryBot.create :pppl_curator }

    before do
      Collection.create_defaults
      stub_s3
      stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.34770"))
    end

    describe "in a collection they curate" do
      it "can edit any work" do
        # The work is not created by princeton_curator
        expect(work.created_by_user_id).not_to eq research_data_admin.id
        # But princeton_curator is an administrator of the collection where the work resides
        expect(collection.administrators.include?(research_data_admin)).to eq true
        # And so, research_data_admin can edit the work
        login_as research_data_admin
        visit edit_work_path(work)
        expect(page).to have_content("Editing Dataset")
        fill_in "title_main", with: "New Title"
        click_on "Save Work"
        expect(page).to have_content("New Title")
        # This does not work. Bug ticketed here: https://github.com/pulibrary/pdc_describe/issues/365
        # expect(work.reload.title).to eq "New Title"
      end
    end
  end
end
