# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Adding a Provenance note", type: :system, js: true do
  let(:work) { FactoryBot.create(:draft_work, created_by_user_id: user) }

  context "A user that does not have permissions to edit the provenance" do
    let(:user) { FactoryBot.create(:user) }
    it "does not show the form" do
        login_as user
      pending "This should test that the page does not have the form"
    end
  end

  context "A user that does has permissions to edit the provenance" do
    let(:user) { FactoryBot.create(:user, uid: config.provenance_message_writers.first) }
    it "does show the form" do
      pending "This should test that the page does have the form"
    end
  end
end