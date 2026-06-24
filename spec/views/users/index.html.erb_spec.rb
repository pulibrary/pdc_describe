# frozen_string_literal: true
require "rails_helper"

describe "/users", type: :system do
  context "for logged-out users" do
    it "renders the log-in prompt and not the authenticated content" do
      visit "/users"
      expect(page).to have_text("Log in")
      expect(page).not_to have_text("A user who is the curator of a work will receive email notifications about that work from the system, regardless of their email notification settings.")
    end
  end

  context "for logged-in users" do
    let(:super_admin) { FactoryBot.create :super_admin_user }
    let(:research_data_moderator) { FactoryBot.create :research_data_moderator }
    let(:pppl_moderator) { FactoryBot.create :pppl_moderator }
    let(:princeton_submitter_1) { FactoryBot.create :princeton_submitter }
    let(:princeton_submitter_2) { FactoryBot.create :princeton_submitter }
    before do
      login_as super_admin
      login_as research_data_moderator
      login_as pppl_moderator
      login_as princeton_submitter_1
      login_as princeton_submitter_2
    end

    context "for logged-in submitters" do
      before do
        login_as princeton_submitter_1
      end
      it "does not render the log-in prompt, but also does not render the Users page" do
        visit "/users"
        expect(page).not_to have_text("Log in")
        expect(page).not_to have_text("A user who is the curator of a work will receive email notifications about that work from the system, regardless of their email notification settings.")
      end
    end

    context "for logged-in admin users with all info" do
      before do
        login_as super_admin
      end
      it "renders the Users page" do
        visit "/users"
        expect(page).to have_text("Users")
        expect(page).to have_text("A user who is the curator of a work will receive email notifications about that work from the system, regardless of their email notification settings.")
        expect(page).to have_text(research_data_moderator.full_name)
      end
    end

    context "for logged-in research data moderators" do
      before do
        login_as research_data_moderator
      end
      it "renders the Users page with all info" do
        visit "/users"
        expect(page).to have_text("Users")
        expect(page).to have_text("A user who is the curator of a work will receive email notifications about that work from the system, regardless of their email notification settings.")
        expect(page).to have_text("Princeton Research Data Service (PRDS)")
        expect(page).to have_text("Princeton Plasma Physics Lab (PPPL)")
      end
    end
  end
end
