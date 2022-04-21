# frozen_string_literal: true
require "rails_helper"

RSpec.describe Work, type: :model do
  let(:user) { FactoryBot.create :user }
  let(:collection) { FactoryBot.create :research_data }

  it "creates a skeleton dataset" do
    work = described_class.create_skeleton("test title", user.id, collection.id, "DATASET")
    expect(work.created_by_user.id).to eq user.id
    expect(work.collection.id).to eq collection.id
  end

  it "prevents datasets with no users" do
    expect { described_class.create_skeleton("test title", 0, collection.id, "DATASET") }.to raise_error
  end

  it "prevents datasets with no collections" do
    expect { described_class.create_skeleton("test title", user.id, 0, "DATASET") }.to raise_error
  end

  it "approves works and records the change history" do
    work = described_class.create_skeleton("test title", user.id, collection.id, "DATASET")
    work.approve(user)
    expect(work.state_history.first.state).to eq "APPROVED"
  end

  it "withdraw works and records the change history" do
    work = described_class.create_skeleton("test title", user.id, collection.id, "DATASET")
    work.withdraw(user)
    expect(work.state_history.first.state).to eq "WITHDRAWN"
  end

  it "resubmit works and records the change history" do
    work = described_class.create_skeleton("test title", user.id, collection.id, "DATASET")
    work.resubmit(user)
    expect(work.state_history.first.state).to eq "AWAITING-APPROVAL"
  end
end
