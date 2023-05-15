# frozen_string_literal: true
require "rails_helper"

RSpec.describe WorkMigrationController do
  let(:work) { FactoryBot.create :draft_work }
  let(:user) { FactoryBot.create :research_data_moderator }
  it "does nothing if no ark is set" do
    sign_in user
    post :migrate, params: { id: work.id }
    expect(response).to redirect_to work_path(work)
    expect(flash[:notice]).to eq("The ark is blank, no migration from Dataspace is possible")
  end

  context "when the ark is set" do
    let(:work) { FactoryBot.create :draft_work, ark: "ark:/88435/dsp01zc77st047" }
    let(:fake_dpsace_data) do
      instance_double(PULDspaceMigrate, migrate: true, migration_message: "Migration for 3 files was queued for processing", migration_snapshot: MigrationUploadSnapshot.new, file_keys: ["a", "b"],
                                        directory_keys: ["1", "2"])
    end

    it "migrates the files using a PULDspaceMigrate instance", mock_ezid_api: true do
      allow(PULDspaceMigrate).to receive(:new).and_return(fake_dpsace_data)
      expect(work.work_activity.count).to eq(0)
      sign_in user
      post :migrate, params: { id: work.id }
      expect(response).to redirect_to work_path(work)
      expect(flash[:notice]).to eq("Migration for 3 files was queued for processing")
      expect(work.work_activity.count).to eq(1)
      expect(work.work_activity.first.message).to eq("{\"migration_id\":null,\"message\":\"Migration for 3 files was queued for processing\",\"file_count\":2,\"directory_count\":2}")
    end
  end

  context "when the user is not an admin" do
    let(:user) { FactoryBot.create :user }

    it "does nothing" do
      sign_in user
      allow(Honeybadger).to receive(:notify)
      post :migrate, params: { id: work.id }
      expect(response).to redirect_to work_path(work)
      expect(flash[:notice]).to eq("Unauthorized migration")
      expect(Honeybadger).to have_received(:notify)
    end
  end
end
