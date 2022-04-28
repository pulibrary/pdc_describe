# frozen_string_literal: true
require "rails_helper"

RSpec.describe Work, type: :model do
  let(:user) { FactoryBot.create :user }
  let(:collection) { FactoryBot.create :collection }

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

  describe "#created_by_user" do
    context "when the ID is invalid" do
      subject(:work) { described_class.create_skeleton(title, user_id, collection_id, work_type) }
      let(:title) { "test title" }
      let(:user_id) { user.id }
      let(:collection_id) { collection.id }
      let(:work_type) { "DATASET" }

      before do
        allow(User).to receive(:find).and_raise(ActiveRecord::RecordNotFound)
      end

      it "returns a nil" do
        expect(work.created_by_user).to be nil
      end
    end
  end

  describe "#dublin_core=" do
    subject(:work) { described_class.create_skeleton(title, user_id, collection_id, work_type) }
    let(:title) { "test title" }
    let(:user_id) { user.id }
    let(:collection_id) { collection.id }
    let(:work_type) { "DATASET" }

    context "when it is mutated with invalid JSON" do
      it "raises an error" do
        expect { work.dublin_core = "{" }.to raise_error(ArgumentError, "Invalid JSON passed to Work#dublin_core=: 809: unexpected token at '{'")
      end
    end
  end
end
