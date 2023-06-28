# frozen_string_literal: true
require "rails_helper"

RSpec.describe WorkList, type: :model do
  let(:user) { FactoryBot.create :user }
  let(:user_other) { FactoryBot.create :user }
  let(:super_admin_user) { FactoryBot.create :super_admin_user }
  let(:work) { FactoryBot.create(:draft_work) }
  let(:work2) { FactoryBot.create(:draft_work) }

  let(:rd_user) { FactoryBot.create :princeton_submitter }

  let(:pppl_user) { FactoryBot.create :pppl_submitter }

  let(:curator_user) do
    FactoryBot.create :user, groups_to_admin: [Group.research_data]
  end

  # Please see spec/support/ezid_specs.rb
  let(:ezid) { @ezid }
  let(:identifier) { @identifier }
  let(:attachment_url) { /#{Regexp.escape("https://example-bucket.s3.amazonaws.com/")}/ }

  describe "#unfinished_works" do
    before do
      FactoryBot.create(:approved_work, created_by_user_id: user.id)
      FactoryBot.create(:draft_work, created_by_user_id: user.id)
      FactoryBot.create(:draft_work, created_by_user_id: user.id)
      FactoryBot.create(:draft_work, created_by_user_id: pppl_user.id, group_id: Group.plasma_laboratory.id)
      # Create the dataset for `rd_user` and @mention `user`
      ds = FactoryBot.create(:draft_work, created_by_user_id: rd_user.id)
      WorkActivity.add_work_activity(ds.id, "Tagging @#{user.uid} in this dataset", rd_user.id, activity_type: WorkActivity::SYSTEM)
    end

    it "for a typical user retrieves only the datasets created by the user or where the user is tagged" do
      user_datasets = described_class.unfinished_works(user)
      expect(user_datasets.count).to be 3
      expect(user_datasets.count { |ds| ds.created_by_user_id == user.id }).to be 2
      expect(user_datasets.count { |ds| ds.created_by_user_id == rd_user.id }).to be 1
    end

    it "for a curator retrieves dataset created in collections they can curate" do
      expect(described_class.unfinished_works(curator_user).length).to eq(3)
    end

    it "for super_admins retrieves for all collections" do
      expect(described_class.unfinished_works(super_admin_user).length).to eq(4)
    end
  end

  describe "#completed_works" do
    before do
      allow(S3QueryService).to receive(:new).and_return(mock_s3_query_service)
    end

    before do
      FactoryBot.create(:approved_work, created_by_user_id: user.id)
      FactoryBot.create(:awaiting_approval_work, created_by_user_id: user.id)
      FactoryBot.create(:draft_work, created_by_user_id: user.id)
      FactoryBot.create(:approved_work, created_by_user_id: pppl_user.id, group_id: Group.plasma_laboratory.id)
      # Create the dataset for `rd_user` and @mention `user`
      ds = FactoryBot.create(:approved_work, created_by_user_id: rd_user.id)
      WorkActivity.add_work_activity(ds.id, "Tagging @#{user.uid} in this dataset", rd_user.id, activity_type: WorkActivity::SYSTEM)
    end

    it "for a typical user retrieves only the datasets created by the user or where the user is tagged" do
      user_datasets = described_class.completed_works(user)
      expect(user_datasets.count).to be 2
      expect(user_datasets.count { |ds| ds.created_by_user_id == user.id }).to be 1
      expect(user_datasets.count { |ds| ds.created_by_user_id == rd_user.id }).to be 1
    end

    it "for a curator retrieves dataset created in collections they can curate" do
      expect(described_class.completed_works(curator_user).length).to eq(2)
    end

    it "for super_admins retrieves for all collections" do
      expect(described_class.completed_works(super_admin_user).length).to eq(3)
    end
  end

  describe "#withdrawn_works", mock_s3_query_service: false do
    before do
      allow(S3QueryService).to receive(:new).and_return(mock_s3_query_service)
      work = FactoryBot.create(:approved_work, created_by_user_id: user.id)
      work.withdraw!(user)
      FactoryBot.create(:awaiting_approval_work, created_by_user_id: user.id)
      FactoryBot.create(:draft_work, created_by_user_id: user.id)
      pppl_work = FactoryBot.create(:approved_work, created_by_user_id: pppl_user.id, group_id: Group.plasma_laboratory.id)
      pppl_work.withdraw!(user)
      # Create the dataset for `rd_user` and @mention `user`
      ds = FactoryBot.create(:approved_work, created_by_user_id: rd_user.id)
      ds.withdraw!(rd_user)
      WorkActivity.add_work_activity(ds.id, "Tagging @#{user.uid} in this dataset", rd_user.id, activity_type: WorkActivity::SYSTEM)
    end

    it "for a typical user retrieves only the datasets created by the user or where the user is tagged" do
      user_datasets = described_class.withdrawn_works(user)
      expect(user_datasets.count).to be 2
      expect(user_datasets.count { |ds| ds.created_by_user_id == user.id }).to be 1
      expect(user_datasets.count { |ds| ds.created_by_user_id == rd_user.id }).to be 1
    end

    it "for a curator retrieves dataset created in collections they can curate" do
      expect(described_class.withdrawn_works(curator_user).length).to eq(2)
    end

    it "for super_admins retrieves for all collections" do
      expect(described_class.withdrawn_works(super_admin_user).length).to eq(3)
    end
  end
end
