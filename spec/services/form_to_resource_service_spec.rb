# frozen_string_literal: true
require "rails_helper"

describe FormToResourceService do
  describe ".convert" do
    let(:work) { FactoryBot.create(:shakespeare_and_company_work) }
    let(:collection) { work.collection }
    let(:params) do
      {
        id: work.id,
        title_main: work.title,
        collection_id: collection.id,
        title_1: "the subtitle",
        title_type_1: "Subtitle",
        existing_title_count: "1",
        new_title_count: "1",
        given_name_1: "Toni",
        family_name_1: "Morrison",
        sequence_1: "1",
        given_name_2: "Sonia",
        family_name_2: "Sotomayor",
        sequence_2: "1",
        orcid_2: "1234-1234-1234-1234",
        creator_count: "1",
        new_creator_count: "1",
        resource_type: "Dataset",
        resource_type_general: "Audiovisual",
        related_identifier_1: "",
        related_identifier_type_1: "",
        relation_type_1: "",
        related_object_count: "1"
      }.with_indifferent_access
    end
    let(:current_user) { FactoryBot.create(:user) }
    let(:resource) { described_class.convert(params, work) }

    it "processes titles" do
      resource
      expect(resource.titles).to be_an(Array)
      expect(resource.titles.length).to eq(2)

      first_title = resource.titles.first
      expect(first_title.title).to eq("Shakespeare and Company Project Dataset: Lending Library Members, Books, Events")
      expect(first_title.title_type).to be nil

      last_title = resource.titles.last
      expect(last_title.title).to eq("the subtitle")
      expect(last_title.title_type).to eq("Subtitle")
    end

    it "handles resource_type_general" do
      resource
      expect(resource.resource_type_general).to eq("Audiovisual")
    end

    it "does not include blank related objects" do
      expect(resource.related_objects.count).to eq(0)
    end
  end
end
