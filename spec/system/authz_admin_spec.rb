# frozen_string_literal: true
require "rails_helper"
##
# A group admin is a user who has admin rights on a given group
RSpec.describe "Authz for curators", type: :system, js: true do
  describe "A curator" do
    let(:research_data_moderator) { FactoryBot.create :research_data_moderator }
    let(:work) { FactoryBot.create(:shakespeare_and_company_work) }
    let(:group) { Group.find(work.collection_id) }
    let(:new_submitter) { FactoryBot.create :pppl_submitter }
    let(:pppl_moderator) { FactoryBot.create :pppl_moderator }

    before do
      Group.create_defaults
      stub_s3
      stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.34770"))
    end

    describe "in a group they curate" do
      it "can edit any work" do
        # The work is not created by princeton_curator
        expect(work.created_by_user_id).not_to eq research_data_moderator.id
        # But princeton_curator is an administrator of the group where the work resides
        expect(group.administrators.include?(research_data_moderator)).to eq true
        # And so, research_data_moderator can edit the work
        login_as research_data_moderator
        visit edit_work_path(work)
        expect(page).to have_content("Editing Dataset")
        fill_in "title_main", with: "New Title", fill_options: { clear: :backspace }
        click_on "Save Work"
        expect(page).to have_content("New Title")
        expect(work.reload.title).to eq "New Title"
      end

      it "can add submitters to the group" do
        login_as research_data_moderator
        expect(research_data_moderator.can_admin?(Group.research_data)).to eq true
        expect(new_submitter.can_submit?(Group.research_data)).to eq false
        visit edit_group_path(Group.research_data)
        fill_in "submitter-uid-to-add", with: new_submitter.uid
        click_on "Add Submitter"
        expect(page).to have_content new_submitter.uid
        expect(new_submitter.can_submit?(Group.research_data)).to eq true
      end

      it "can add admins to the group" do
        login_as research_data_moderator
        expect(research_data_moderator.can_admin?(Group.research_data)).to eq true
        expect(new_submitter.can_admin?(Group.research_data)).to eq false
        visit edit_group_path(Group.research_data)
        fill_in "admin-uid-to-add", with: new_submitter.uid
        click_on "Add Moderator"
        expect(page).to have_content new_submitter.uid
        expect(new_submitter.reload.can_admin?(Group.research_data)).to eq true
      end
    end

    describe "in a group they do NOT curate" do
      let(:work) { FactoryBot.create(:tokamak_work) }
      let(:group) { Group.find(work.collection_id) }

      it "can NOT add admins" do
        login_as research_data_moderator
        expect(research_data_moderator.can_admin?(Group.research_data)).to eq true
        expect(research_data_moderator.can_admin?(Group.plasma_laboratory)).to eq false
        visit group_path(Group.plasma_laboratory)
        expect(page).not_to have_content "Add Submitter"
        expect(page).not_to have_content "Add Moderator"
      end

      it "can NOT edit works" do
        expect(work.created_by_user_id).not_to eq research_data_moderator.id
        # research_data_moderator is NOT an administrator of the group where the work resides
        expect(group.administrators.include?(research_data_moderator)).to eq false
        # And so, research_data_moderator can NOT edit the work
        login_as research_data_moderator
        visit edit_work_path(work)
        expect(current_path).to eq root_path
        expect(page).not_to have_content("Editing Dataset")
        expect(page).to have_content("You do not have permission to edit this work")
      end

      context "with submitter rights" do
        let(:other_work) { FactoryBot.create :draft_work, created_by_user_id: research_data_moderator.id, group: group }
        let(:user_work) { FactoryBot.create :draft_work }
        before do
          research_data_moderator.add_role :submitter, group
          other_work
          user_work
        end
        it "allows them to see a work they submitted on thier dashboard" do
          login_as research_data_moderator
          visit user_path(research_data_moderator)
          expect(page).to have_content("Curator")
          expect(page).to have_content(user_work.title)
          expect(page).to have_content(other_work.title)
        end
      end
    end

    describe "menu at the top" do
      it "should see the Create Dataset option" do
        login_as research_data_moderator
        visit user_path(research_data_moderator)
        expect(page.html.include?("Create Dataset")).to be true
      end
    end
  end
end
