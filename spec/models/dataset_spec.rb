# frozen_string_literal: true
require "rails_helper"

RSpec.describe Dataset, type: :model do
  let(:user) { FactoryBot.create :user }
  let(:collection) { FactoryBot.create :collection }

  it "creates a skeleton dataset" do
    ds = described_class.create_skeleton("test title", user.id, collection.id)
    expect(ds.created_by_user.id).to eq user.id
    expect(ds.work.collection.id).to eq collection.id
  end

  it "prevents datasets with no users" do
    expect { described_class.create_skeleton("test title", 0, collection.id) }.to raise_error
  end

  it "prevents datasets with no collections" do
    expect { described_class.create_skeleton("test title", user.id, 0) }.to raise_error
  end
end
