# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Curator Controlled metadata tab", type: :system do
  let(:draft_work) do
    resource = FactoryBot.build(:resource, creators: [PDCMetadata::Creator.new_person("Harriet", "Tubman", "1234-5678-9012-3456")])
    FactoryBot.create(:draft_work, resource: resource, created_by_user_id: user.id, collection: Collection.research_data)
  end

  before do
    stub_s3
    sign_in user
    visit edit_work_path(draft_work)
    click_on "Curator Controlled"
  end

  context "As a princeton submitter" do
    let(:user) { FactoryBot.create :princeton_submitter }
    it "does not allow editing of curator controlled fields", js: true, mock_ezid_api: true do
      # I can not edit curator fields
      expect(page).to have_content("ARK")
      expect(page).not_to have_css("#ark.input-text-long")
      expect(page).to have_content("Version")
      expect(page).not_to have_css("#version_number.input-version")
      expect(page).to have_content("Collection Tags")
      expect(page).not_to have_css("#collection_tags.input-collection-tags")

      # I can edit other fields
      click_on "Additional Metadata"
      fill_in "keywords", with: "red, yellow, green"

      # I can edit other fields
      click_on "Required Metadata"
      fill_in "description", with: "The work can be changed"
      click_on "Save Work"
      expect(draft_work.reload.resource.description).to eq "The work can be changed"
    end
  end
  context "As a collection admin" do
    let(:user) { FactoryBot.create :research_data_moderator }

    it "allows editing of curator controlled fields", js: true, mock_ezid_api: true do
      expect(page).to have_css("#ark.input-text-long")
      fill_in "ark", with: "http://arks.princeton.edu/ark:/88435/dsp01hx11xj13h"
      fill_in "collection_tags", with: "ABC, 123"
      click_on "Save Work"
      expect(draft_work.reload.ark).to eq "ark:/88435/dsp01hx11xj13h"
      expect(draft_work.resource.collection_tags).to eq(["ABC", "123"])
    end
  end

  context "As a super admin" do
    let(:user) { FactoryBot.create :super_admin_user }

    it "allows editing of curator controlled fields", js: true, mock_ezid_api: true do
      expect(page).to have_css("#ark.input-text-long")
      fill_in "ark", with: "http://arks.princeton.edu/ark:/88435/dsp01hx11xj13h"
      fill_in "collection_tags", with: "ABC, 123"
      click_on "Save Work"
      expect(draft_work.reload.ark).to eq "ark:/88435/dsp01hx11xj13h"
      expect(draft_work.resource.collection_tags).to eq(["ABC", "123"])
    end
  end
end
