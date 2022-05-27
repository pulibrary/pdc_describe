# frozen_string_literal: true
require "rails_helper"

RSpec.describe Work, type: :model, mock_ezid_api: true do
  let(:user) { FactoryBot.create :user }
  let(:collection) { Collection.research_data }
  let(:user_other) { FactoryBot.create :user }
  let(:superadmin_user) { User.from_cas(OmniAuth::AuthHash.new(provider: "cas", uid: "fake1", extra: { mail: "fake@princeton.edu" })) }
  let(:doi) { "https://doi.org/10.34770/0q6b-cj27" }
  let(:work) do
    datacite_resource = PULDatacite::Resource.new
    datacite_resource.creators << PULDatacite::Creator.new_person("Harriet", "Tubman")
    described_class.create_dataset("test title", user.id, collection.id, datacite_resource)
  end

  # Please see spec/support/ezid_specs.rb
  let(:ezid) { @ezid }
  let(:identifier) { @identifier }

  it "creates a skeleton dataset with a DOI and an ARK" do
    expect(work.created_by_user.id).to eq user.id
    expect(work.collection.id).to eq collection.id
    expect(work.doi).to be_present
    expect(work.ark).to be_present
  end

  it "prevents datasets with no users" do
    expect { described_class.create_dataset("test title", 0, collection.id) }.to raise_error
  end

  it "prevents datasets with no collections" do
    expect { described_class.create_dataset("test title", user.id, 0) }.to raise_error
  end

  it "approves works and records the change history" do
    work.approve(user)
    expect(work.state_history.first.state).to eq "APPROVED"
  end

  it "withdraw works and records the change history" do
    work.withdraw(user)
    expect(work.state_history.first.state).to eq "WITHDRAWN"
  end

  it "resubmit works and records the change history" do
    work.resubmit(user)
    expect(work.state_history.first.state).to eq "AWAITING-APPROVAL"
  end

  describe "#created_by_user" do
    context "when the ID is invalid" do
      subject(:work) { described_class.create_dataset(title, user_id, collection_id) }
      let(:title) { "test title" }
      let(:user_id) { user.id }
      let(:collection_id) { collection.id }

      before do
        allow(User).to receive(:find).and_raise(ActiveRecord::RecordNotFound)
      end

      it "returns a nil" do
        expect(work.created_by_user).to be nil
      end
    end
  end

  describe "#dublin_core=" do
    subject(:work) { described_class.create_skeleton(title, user_id, collection_id, work_type, "DUBLINCORE") }
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

  context "when created with an existing ARK" do
    context "and when the ARK is valid" do
      let(:ezid) { "ark:/99999/dsp01qb98mj541" }

      around do |example|
        Rails.configuration.update_ark_url = true
        example.run
        Rails.configuration.update_ark_url = false
      end

      it "does not mint a new ARK" do
        expect(work.persisted?).not_to be false
        work.ark = ezid
        work.save

        expect(work.persisted?).to be true
        expect(work.ark).to eq(ezid)
      end
    end

    context "and when the ARK is invalid" do
      before do
        # The HTTP call to EZID will fail because the id is invalid
        allow(Ezid::Identifier).to receive(:find).and_raise(Net::HTTPServerException, '400 "Bad Request"')
      end

      it "raises an error" do
        expect(work.persisted?).not_to be false
        bad_ezid = "ark:/bad-99999/fk4tq65d6k"
        work.ark = bad_ezid
        expect { work.save! }.to raise_error(ActiveRecord::RecordInvalid, "Validation failed: Invalid ARK provided for the Work: #{bad_ezid}")
      end
    end
  end

  context "when updating the ARK" do
    before { allow(Ark).to receive(:update) }
    let(:ezid) { "ark:/99999/dsp01qb98mj541" }

    around do |example|
      Rails.configuration.update_ark_url = true
      example.run
      Rails.configuration.update_ark_url = false
    end

    it "updates the ARK metadata" do
      work.ark = ezid
      work.save
      # one on create + one on update
      expect(Ark).to have_received(:update).exactly(2).times
    end
  end

  it "returns datasets waiting for approval depending on the user" do
    described_class.create_dataset("test title", user.id, collection.id)
    described_class.create_dataset("test title", user_other.id, collection.id)

    # Superadmins can approve pending works
    awaiting = described_class.admin_works_by_user_state(superadmin_user, "AWAITING-APPROVAL")
    expect(awaiting.count > 0).to be true

    # Normal users don't get anything
    awaiting = described_class.admin_works_by_user_state(user, "AWAITING-APPROVAL")
    expect(awaiting.count).to be 0
  end

  context "linked to a work" do
    let(:work) { FactoryBot.create(:shakespeare_and_company_work) }
    it "has a DOI" do
      expect(work.title).to eq "Shakespeare and Company Project Dataset: Lending Library Members, Books, Events"
      expect(work.doi).to eq "https://doi.org/10.34770/pe9w-x904"
    end
  end

  describe ".my_datasets" do
    before do
      described_class.create_dataset("test title", user.id, collection.id)
      described_class.create_dataset("test title", user.id, collection.id)
    end

    it "retrieves Dataset models associated with a given User" do
      expect(described_class.my_works(user).length).to eq(2)
    end
  end
end
