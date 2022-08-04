# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Datacite records", type: :system, mock_ezid_api: true do
  context "datacite record" do
    let(:work) { FactoryBot.create(:shakespeare_and_company_work) }
    let(:user) { FactoryBot.create :user }

    before do
      sign_in user
    end

    it "work has a json rendering of the datacite" do
      json = JSON.parse(work.data_cite)
      expect(json["titles"].first["title"]).to eq "Shakespeare and Company Project Dataset: Lending Library Members, Books, Events"
    end

    it "work has an xml rendering of the datacite" do
      xml_output = work.datacite_resource.datacite_mapping.write_xml
      record = Datacite::Mapping::Resource.parse_xml(xml_output)
      expect(record.class).to eq Datacite::Mapping::Resource
      expect(record.identifier.value).to eq "https://doi.org/10.34770/pe9w-x904"
    end

    # TODO: RENDER XML IN THE BROWSER
    xit "Renders an xml serialization of the datacite in the browser", js: true do
      visit datacite_work_path(work)
      byebug
    end

    xit "Validates the record and prints any errors", js: true do
      visit datacite_validate_work_path(work)
      expect(page).to have_content "The value has a length of '0'"
    end
  end
end
