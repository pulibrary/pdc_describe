# frozen_string_literal: true
require "rails_helper"

describe "application accessibility", type: :system, js: true do
  before { sign_in user }
  before { Collection.create_defaults }

  let(:user) { FactoryBot.create :princeton_submitter }
  let(:collection) { Collection.first }

  context "when browsing the homepage" do
    it "complies with WCAG 2.0 AA and Section 508" do
      visit "/"
      expect(page).to be_axe_clean
        .according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa, :section508)
        .skipping(:'color-contrast') # false positives
    end
  end

  context "when viewing the user dashboard" do
    it "complies with WCAG 2.0 AA and Section 508" do
      visit user_path(user)
      expect(page).to be_axe_clean
        .according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa, :section508)
        .skipping(:'color-contrast') # false positives
    end
  end

  context "when viewing the collections list" do
    it "complies with WCAG 2.0 AA and Section 508" do
      visit "/collections"
      expect(page).to be_axe_clean
        .according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa, :section508)
        .skipping(:'color-contrast') # false positives
    end
  end

  context "when viewing an individual collection show page" do
    it "complies with WCAG 2.0 AA and Section 508" do
      visit collection_path(collection)
      expect(page).to be_axe_clean
        .according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa, :section508)
        .skipping(:'color-contrast') # false positives
    end
  end

  context "when viewing the works list" do
    it "complies with WCAG 2.0 AA and Section 508" do
      visit "/works"
      expect(page).to be_axe_clean
        .according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa, :section508)
        .skipping(:'color-contrast') # false positives
    end
  end

  context "when viewing an individual work show page" do
    it "complies with WCAG 2.0 AA and Section 508" do
      stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.34770"))
      stub_s3
      resource = PDCMetadata::Resource.new(title: "Test dataset")
      resource.creators << PDCMetadata::Creator.new_person("Harriet", "Tubman", "1234-5678-9012-3456")
      resource.ark = "ark:/99999/dsp01qb98mj541"
      work = FactoryBot.create(:draft_work, created_by_user_id: user.id, collection_id: user.default_collection_id, resource: resource)
      visit work_path(work)
      expect(page).to be_axe_clean
        .according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa, :section508)
        .skipping(:'color-contrast') # false positives
    end
  end
end
