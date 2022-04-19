# frozen_string_literal: true
require "rails_helper"

RSpec.describe Dataset, type: :model do
  let(:user) { FactoryBot.create :user }
  let(:collection) { FactoryBot.create :collection }

  it "creates a skeleton dataset and links it to a new work" do
    ds = described_class.create_skeleton("test title", user.id, collection.id)
    expect(ds.created_by_user.id).to eq user.id
    expect(ds.work.collection.id).to eq collection.id
    expect(ds.ark).to be_present
  end
end
