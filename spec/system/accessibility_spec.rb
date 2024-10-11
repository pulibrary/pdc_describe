# frozen_string_literal: true
require "rails_helper"

describe "application accessibility", type: :system, js: true do
  before { sign_in user }
  before { Group.create_defaults }

  let(:user) { FactoryBot.create :princeton_submitter }
  let(:group) { Group.first }

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

  context "when viewing the groups list" do
    it "complies with WCAG 2.0 AA and Section 508" do
      visit "/groups"
      expect(page).to be_axe_clean
        .according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa, :section508)
        .skipping(:'color-contrast') # false positives
    end
  end

  context "when viewing an individual group show page" do
    it "complies with WCAG 2.0 AA and Section 508" do
      visit group_path(group)
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
      WebMock.allow_net_connect!
      stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.34770"))
      stub_s3
      work = FactoryBot.create(:distinct_cytoskeletal_proteins_work)

      visit work_path(work)
      expect(page).to be_axe_clean
        .according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa, :section508)
        .skipping(:'color-contrast') # false positives
    end
  end
end
