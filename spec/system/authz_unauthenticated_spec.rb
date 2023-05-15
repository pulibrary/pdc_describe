# frozen_string_literal: true
require "rails_helper"
##
# A non-authenticated user cannot get to any edit screens, they always get redirected back
# to the root of the application
RSpec.describe "Authz for non-authenticated users", type: :system, js: true do
  describe "A non-authenticated user" do
    context "works" do
      let(:work) { FactoryBot.create(:shakespeare_and_company_work) }

      # As a non-authenticated user if I try to go directly to the work/ dataset show page,
      # I am redirected to the sign_in page
      it "cannot go directly to a work show page" do
        visit work_path(work)
        expect(current_path).to eq "/sign_in"
      end

      # As a non-authenticated user if I try to go directly to the work/ dataset edit page,
      # I am redirected to the sign_in page
      it "cannot go directly to a work show page" do
        visit edit_work_path(work)
        expect(current_path).to eq "/sign_in"
      end
    end

    context "groups" do
      before do
        Group.create_defaults
      end
      # As a non-authenticated user if I try to go directly to a group page,
      # I am redirected to the sign_in page
      it "cannot go directly to a group show page" do
        visit group_path(Group.first)
        expect(current_path).to eq "/sign_in"
      end

      # As a non-authenticated user if I try to go directly to a group edit page,
      # I am redirected to the sign_in page
      it "cannot go directly to a group edit page" do
        visit edit_group_path(Group.first)
        expect(current_path).to eq "/sign_in"
      end
    end
  end
end
