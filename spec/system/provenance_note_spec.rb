# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Adding a Provenance note", type: :system, js: true do

  context "A user that does not have permissions to edit the provenance" do
    let(:any_user) { FactoryBot.create(:user) }
    let(:work) { FactoryBot.create(:draft_work, created_by_user_id: any_user.id) }
    it "does not show the form" do
      login_as any_user
      visit work_path(work)
      expect(page).to have_content(work.title)
      expect(page).not_to have_button("Add Provenance Note")
    end
  end

  context "A user that does has permissions to edit the provenance" do
    let(:provenace_writer_user) { FactoryBot.create(:user, uid: Rails.configuration.provenance_message_writers.first) }
    let(:work) { FactoryBot.create(:draft_work, created_by_user_id: provenace_writer_user.id) }
    it "does show the form" do
      login_as provenace_writer_user
      pending "This should test that the page does have the form"
    end
  end
end