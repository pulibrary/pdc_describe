# frozen_string_literal: true
require "rails_helper"
##
# A non-authenticated user cannot get to any edit screens, they always get redirected back
# to the root of the application
RSpec.describe "Authz for non-authenticated users", type: :system, js: true, mock_ezid_api: true do
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

    context "collections" do
      before do
        Collection.create_defaults
      end
      # As a non-authenticated user if I try to go directly to a collection page,
      # I am redirected to the sign_in page
      it "cannot go directly to a collection show page" do
        visit collection_path(Collection.first)
        expect(current_path).to eq "/sign_in"
      end

      # As a non-authenticated user if I try to go directly to a collection edit page,
      # I am redirected to the sign_in page
      it "cannot go directly to a collection edit page" do
        visit edit_collection_path(Collection.first)
        expect(current_path).to eq "/sign_in"
      end
    end
  end
end
