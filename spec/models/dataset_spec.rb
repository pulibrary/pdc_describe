# frozen_string_literal: true
require "rails_helper"

RSpec.describe Dataset, type: :model, mock_ezid_api: true do
  before { Collection.create_defaults }

  let(:collection) { Collection.default }
  let(:user) { FactoryBot.create :user }
  let(:user_other) { FactoryBot.create :user }
  let(:superadmin_user) { User.from_cas(OmniAuth::AuthHash.new(provider: "cas", uid: "fake1", extra: { mail: "fake@princeton.edu" })) }
  let(:doi) { "https://doi.org/10.34770/0q6b-cj27" }
  # Please see spec/support/ezid_specs.rb
  let(:ezid) { @ezid }
  let(:identifier) { @identifier }

  it "creates a skeleton dataset and links it to a new work" do
    ds = described_class.create_skeleton("test title", user.id, collection.id)
    expect(ds.created_by_user.id).to eq user.id
    expect(ds.work.collection.id).to eq collection.id
    expect(ds.ark).to be_blank
    expect(ds.doi).to be_blank
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
        allow(Ezid::Identifier).to receive(:find).and_raise(Net::HTTPServerException, '400 "Bad Request"')
      end

      # TODO: re-enable this once we fix the ARK validation to account for test ARKs
      # See https://github.com/pulibrary/pdc_describe/issues/124
      # it "raises an error" do
      #   expect(data_set.persisted?).not_to be false
      #   data_set.ark = ezid
      #   expect { data_set.save! }.to raise_error("Validation failed: Invalid ARK provided for the Dataset: #{ezid}")
      # end
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
      expect(dataset.title).to eq "Shakespeare and Company Project Dataset: Lending Library Members, Books, Events"
      expect(dataset.doi).to eq "https://doi.org/10.34770/pe9w-x904"
    end
  end

  describe ".my_datasets" do
    subject(:datasets) { described_class.my_datasets(user) }
    let(:ds1) { described_class.create_skeleton("test title", user.id, collection.id) }
    let(:ds2) { described_class.create_skeleton("test title", user.id, collection.id) }
    let(:works) do
      [
        ds1.work,
        ds2.work
      ]
    end

    before do
      works
    end

    it "retrieves Dataset models associated with a given User" do
      expect(datasets).to be_an(Array)
      expect(datasets.length).to eq(2)
    end
  end
end
