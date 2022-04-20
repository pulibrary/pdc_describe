# frozen_string_literal: true
require "rails_helper"

RSpec.describe Dataset, type: :model do
  before { Collection.create_defaults }

  let(:collection) { Collection.default }
  let(:user) { FactoryBot.create :user }
  let(:user_other) { FactoryBot.create :user }
  let(:superadmin_user) { User.from_cas(OmniAuth::AuthHash.new(provider: "cas", uid: "fake1", extra: { mail: "fake@princeton.edu" })) }

  it "creates a skeleton dataset and links it to a new work" do
    ds = described_class.create_skeleton("test title", user.id, collection.id)
    expect(ds.created_by_user.id).to eq user.id
    expect(ds.work.collection.id).to eq collection.id
    expect(ds.ark).to be_blank
  end

  it "mints an ARK on save (and only when needed)" do
    ds = described_class.create_skeleton("test title", user.id, collection.id)
    expect(ds.ark).to be_blank
    ds.save
    expect(ds.ark).to be_present
    original_ark = ds.ark
    ds.save
    expect(ds.ark).to eq original_ark
  end

  it "returns datasets waiting for approval depending on the user" do
    described_class.create_skeleton("test title", user.id, collection.id)
    described_class.create_skeleton("test title", user_other.id, collection.id)

    # Superadmins can approve pending works
    awaiting = described_class.admin_datasets_by_user_state(superadmin_user, "AWAITING-APPROVAL")
    expect(awaiting.count > 0).to be true

    # Normal users don't get anything
    awaiting = described_class.admin_datasets_by_user_state(user, "AWAITING-APPROVAL")
    expect(awaiting.count).to be 0
  end
end
