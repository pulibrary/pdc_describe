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
      expect(page).not_to have_form(add_provenance_note_path(work), :post)
    end
  end

  context "A user that does has permissions to edit the provenance" do
    let(:provenace_writer_user) { FactoryBot.create(:user, uid: Rails.configuration.provenance_message_writers.first) }
    let(:work) { FactoryBot.create(:draft_work, created_by_user_id: provenace_writer_user.id) }
    it "does show the form" do
      login_as provenace_writer_user
      visit work_path(work)
      expect(page).to have_content(work.title)
      expect(page).to have_button("Add Provenance Note")
      expect(page).to have_form(add_provenance_note_path(work), :post)
      fill_in "new-provenance-date", with: "2023-01-02"
      select "File Audit", from: "change_label"
      fill_in "new-provenance-note", with: "test note"
      click_on "Add Provenance Note"
      within ".beads" do
        expect(page).to have_content("file_audit")
        expect(page).not_to have_content("test note")
        page.find(:css, "summary.show-changes").click
        expect(page).to have_content("test note")
      end
    end
  end
end
