# frozen_string_literal: true
require "rails_helper"

RSpec.describe WorkUpdateMetadataService do
  include ActiveJob::TestHelper
  context "a PPPL department name change" do
    let(:work) { FactoryBot.create :pppl_work_with_department_name_change }
    let(:user) { FactoryBot.create :pppl_submitter }
    it "renames PPPL subcommunities" do
      expect(work.resource.subcommunities).to contain_exactly("Plasma Science & Technology", "Fake Subcommunity")
      expect(work.work_activity).to be_empty
      described_class.update_pppl_subcommunities(user)
      work.reload
      expect(work.resource.subcommunities).to contain_exactly("Discovery Plasma Science", "Fake Subcommunity")
      expect(work.work_activity.count).to eq 1
      expect(JSON.parse(work.work_activity.last.message)["subcommunities"].first["action"]).to eq "changed"
    end
  end
end
