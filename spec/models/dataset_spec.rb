# frozen_string_literal: true
require "rails_helper"

RSpec.describe Dataset, type: :model do
  before { Collection.create_defaults }

  let(:collection) { Collection.default }
  let(:user) { FactoryBot.create :user }
  let(:user_other) { FactoryBot.create :user }
  let(:superadmin_user) { User.from_cas(OmniAuth::AuthHash.new(provider: "cas", uid: "fake1", extra: { mail: "fake@princeton.edu" })) }
  let(:doi) { "https://doi.org/10.34770/0q6b-cj27" }
  # This is not `instance_double` given that the `#modify` must be stubbed as is private
  let(:identifier) { double(Ezid::Identifier) }
  let(:ezid_metadata_values) do
    {
      "_updated" => "1611860047",
      "_target" => "https://dataspace.princeton.edu/handle/88435/dsp01qb98mj541",
      "_profile" => "erc",
      "_export" => "yes",
      "_owner" => "pudiglib",
      "_ownergroup" => "pudiglib",
      "_created" => "1611860047",
      "_status" => "public"
    }
  end
  let(:ezid_metadata) do
    Ezid::Metadata.new(ezid_metadata_values)
  end
  let(:ezid) { "ark:/88435/dsp01qb98mj541" }

  before do
    # This is a work-around due to an issue with WebMock
    allow(Ezid::Identifier).to receive(:find).and_return(identifier)

    allow(identifier).to receive(:metadata).and_return(ezid_metadata)
    allow(identifier).to receive(:id).and_return(ezid)
    allow(identifier).to receive(:modify)
  end

  it "creates a skeleton dataset and links it to a new work" do
    ds = described_class.create_skeleton("test title", user.id, collection.id)
    expect(ds.created_by_user.id).to eq user.id
    expect(ds.work.collection.id).to eq collection.id
    expect(ds.ark).to be_blank
    expect(ds.doi).to be_blank
  end

  it "mints an ARK on save (and only when needed)" do
    # This is a work-around due to an issue with WebMock
    allow(Ezid::Identifier).to receive(:find).and_return(identifier)

    ds = described_class.create_skeleton("test title", user.id, collection.id)
    expect(ds.ark).to be_blank
    ds.save
    expect(ds.ark).to be_present
    original_ark = ds.ark
    ds.save
    expect(ds.ark).to eq original_ark
  end

  context "when created with an existing ARK" do
    subject(:data_set) { described_class.create_skeleton("test title", user.id, collection.id) }

    context "and when the ARK is valid" do
      around do |example|
        Rails.configuration.update_ark_url = true
        example.run
        Rails.configuration.update_ark_url = false
      end

      before do
        # stub_request(:get, "https://ezid.cdlib.org/id/#{ezid}").to_return(status: 200, body: response_body)
      end

      it "does not mint a new ARK" do
        expect(data_set.persisted?).not_to be false
        data_set.ark = ezid
        data_set.save

        expect(data_set.persisted?).to be true
        expect(data_set.ark).to eq(ezid)
      end

      it "updates the ARK metadata" do
        data_set = described_class.create_skeleton("test title", user.id, collection.id)

        data_set.ark = ezid
        data_set.save

        expect(identifier).to have_received(:modify)
      end
    end

    context "and when the ARK is invalid" do
      before do
        # This is a work-around due to an issue with WebMock
        allow(Ezid::Identifier).to receive(:find).and_raise(Net::HTTPServerException, '400 "Bad Request"')
      end

      it "raises an error" do
        expect(data_set.persisted?).not_to be false
        data_set.ark = ezid
        expect { data_set.save! }.to raise_error("Validation failed: Invalid ARK provided for the Dataset: #{ezid}")
      end
    end
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

  context "linked to a work" do
    let(:dataset) { FactoryBot.create(:shakespeare_and_company_dataset) }
    it "has a DOI" do
      # This is a work-around due to an issue with WebMock
      allow(Ezid::Identifier).to receive(:find).and_return(identifier)

      expect(dataset.title).to eq "Shakespeare and Company Project Dataset: Lending Library Members, Books, Events"
      expect(dataset.doi).to eq "https://doi.org/10.34770/pe9w-x904"
    end
  end
end
