# frozen_string_literal: true
require "rails_helper"

RSpec.describe WorkPresenter do
  subject(:work_presenter) { described_class.new(work:, current_user:) }

  let(:description) { "This tests the link http://library.princeton.edu. It also has a summary." }
  let(:resource) { FactoryBot.build(:resource, doi: "10.34770/123-abc", description:) }
  let(:work) { FactoryBot.create(:draft_work, resource:) }
  let(:current_user) { work.created_by_user }

  it "delegates methods" do
    expect(work_presenter.group).to eq(work.group)
    expect(work_presenter.resource).to eq(work.resource)
    expect(work_presenter.migrated).to be_falsey
    work.resource.migrated = true
    expect(work_presenter.migrated).to be_truthy
  end

  describe "#description" do
    it "autolinks URLs within the description metadata" do
      expect(work_presenter.description).not_to eq(work.resource.description)
      expect(work_presenter.description).to eq("This tests the link <a href=\"http://library.princeton.edu\" target=\"_blank\">http://library.princeton.edu</a>. It also has a summary.")
    end
  end

  describe "#related_objects" do
    let(:related_doi) { FactoryBot.build(:related_object) }
    let(:related_arxiv) { FactoryBot.build(:related_object_arxiv) }
    let(:related_isbn) { FactoryBot.build(:related_object_isbn) }

    before do
      work.resource.related_objects << related_doi
      work.resource.related_objects << related_arxiv
      work.resource.related_objects << related_isbn
      work.save
    end

    it "formats identifiers in related objects as URLs so they can be links" do
      ro1 = work_presenter.related_objects_link_list[0]
      expect(ro1).to be_instance_of RelatedObjectLink
      expect(ro1.identifier).to eq related_doi.related_identifier
      expect(ro1.relation_type).to eq "IsCitedBy"
      expect(ro1.link).to eq "https://handle.test.datacite.org/#{related_doi.related_identifier}"

      ro2 = work_presenter.related_objects_link_list[1]
      expect(ro2.identifier).to eq related_arxiv.related_identifier
      expect(ro2.relation_type).to eq "IsCitedBy"
      expect(ro2.link).to eq "https://arxiv.org/abs/#{related_arxiv.related_identifier}"

      ro3 = work_presenter.related_objects_link_list[2]
      expect(ro3.identifier).to eq related_isbn.related_identifier
      expect(ro3.relation_type).to eq "IsCitedBy"
      expect(ro3.link).to eq ""
    end

    context "In production" do
      before do
        allow(Rails.configuration.datacite).to receive(:datacommons_url).and_return("https://datacommons.princeton.edu/discovery")
        allow(Rails.configuration.datacite).to receive(:doi_url).and_return("https://doi.org/")
      end

      it "formats identifiers in related objects as URLs so they can be links" do
        ro1 = work_presenter.related_objects_link_list[0]
        expect(ro1).to be_instance_of RelatedObjectLink
        expect(ro1.identifier).to eq related_doi.related_identifier
        expect(ro1.relation_type).to eq "IsCitedBy"
        expect(ro1.link).to eq "https://doi.org/#{related_doi.related_identifier}"

        ro2 = work_presenter.related_objects_link_list[1]
        expect(ro2.identifier).to eq related_arxiv.related_identifier
        expect(ro2.relation_type).to eq "IsCitedBy"
        expect(ro2.link).to eq "https://arxiv.org/abs/#{related_arxiv.related_identifier}"

        ro3 = work_presenter.related_objects_link_list[2]
        expect(ro3.identifier).to eq related_isbn.related_identifier
        expect(ro3.relation_type).to eq "IsCitedBy"
        expect(ro3.link).to eq ""
      end
    end
  end

  describe "#show_complete_button?" do
    let(:group) { Group.default }
    let(:current_user) { FactoryBot.create(:user) }
    let(:depositor) { FactoryBot.create(:user) }
    let(:work) { FactoryBot.create(:draft_work, created_by_user_id: depositor.id, group: current_user.default_group) }

    before do
      Group.create_defaults
      current_user
    end

    context "when the work is not in the draft state" do
      let(:work) { FactoryBot.create(:approved_work, created_by_user_id: depositor.id, group: current_user.default_group) }

      it "does not allow the current user to mark the item complete" do
        expect(work_presenter.group).to eq(work.group)
        expect(work_presenter.show_complete_button?).to be false
      end
    end

    context "when the work belongs to a group" do
      context "and the current user is an admin for the group" do
        let(:current_user) { FactoryBot.create(:user, groups_to_admin: [group]) }

        it "allows the current user to mark the item complete" do
          expect(work_presenter.group).to eq(work.group)
          expect(work_presenter.show_complete_button?).to be true
        end
      end

      it "does not allow the current user to mark the item complete" do
        expect(work_presenter.group).to eq(work.group)
        expect(work_presenter.show_complete_button?).to be false
      end
    end
  end
end
