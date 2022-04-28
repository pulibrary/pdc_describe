# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  before { Collection.create_defaults }

  let(:access_token) { OmniAuth::AuthHash.new(provider: "cas", uid: "who", extra: { mail: "who@princeton.edu" }) }
  let(:access_token_pppl) { OmniAuth::AuthHash.new(provider: "cas", uid: "who", extra: { mail: "who@princeton.edu", departmentnumber: "31000" }) }
  let(:access_token_superadmin) { OmniAuth::AuthHash.new(provider: "cas", uid: "fake1", extra: { mail: "fake@princeton.edu" }) }

  let(:normal_user) { described_class.from_cas(access_token) }
  let(:pppl_user) { described_class.from_cas(access_token_pppl) }
  let(:superadmin_user) { described_class.from_cas(access_token_superadmin) }

  let(:rd_collection) { Collection.where(code: "RD").first }
  let(:pppl_collection) { Collection.where(code: "PPPL").first }

  describe "#from_cas" do
    it "returns a user object with a default collection" do
      user = described_class.from_cas(access_token)
      expect(user).to be_a described_class
      expect(user.default_collection.id).to eq Collection.default.id
    end

    it "sets the proper default collection for a PPPL user" do
      pppl_collection = Collection.where(code: "PPPL").first
      pppl_user = described_class.from_cas(access_token_pppl)
      expect(pppl_user).to be_a described_class
      expect(pppl_user.default_collection.id).to eq pppl_collection.id
    end

    it "updates an existing user with CAS info" do
      # Create a user without CAS info
      described_class.where(uid: "test123").delete_all
      user = described_class.new(uid: "test123", email: "test123@princeton.edu")
      user.save!
      expect(user.display_name).to be nil

      # ...make sure it's updated with CAS info
      cas_info = OmniAuth::AuthHash.new(provider: "cas", uid: "test123", extra: { mail: "test123@princeton.edu", displayname: "Test User 123" })
      user = described_class.from_cas(cas_info)
      expect(user.full_name).to eq "Test User 123"
    end
  end

  describe "#superadmin?" do
    let(:superadmin_access_token) { OmniAuth::AuthHash.new(provider: "cas", uid: "fake1", extra: { mail: "fake@princeton.edu" }) }
    let(:superadmin) { described_class.from_cas(superadmin_access_token) }
    let(:normal_user) { described_class.from_cas(access_token) }

    it "is true if the user is in the superadmin config" do
      expect(superadmin.superadmin?).to eq true
    end

    it "is false if the user is not in the superadmin config" do
      expect(normal_user.superadmin?).to eq false
    end
  end

  describe "#new_for_uid" do
    it "creates the user only once" do
      described_class.where(uid: "test222").delete_all
      user1 = described_class.new_for_uid("test222")
      user2 = described_class.new_for_uid("test222")
      expect(user1.id).to eq user2.id
    end
  end

  describe "#create_default_users" do
    it "creates the default users/collection records" do
      # The data for these tests comes from `default_collections.yml`
      described_class.create_default_users
      user1 = described_class.new_for_uid("user1")
      user2 = described_class.new_for_uid("user2")
      rd = Collection.where(code: "RD").first
      lib = Collection.where(code: "LIB").first
      expect(user1.can_admin?(rd.id)).to be true
      expect(user1.can_admin?(lib.id)).to be false
      expect(user2.can_submit?(rd.id)).to be true
      expect(user2.can_admin?(rd.id)).to be false
    end
  end

  describe "collection access" do
    it "gives full rights to superadmin users" do
      expect(superadmin_user.can_admin?(pppl_collection.id)).to be true
      expect(superadmin_user.can_submit?(pppl_collection.id)).to be true
      expect(superadmin_user.can_admin?(rd_collection.id)).to be true
      expect(superadmin_user.can_submit?(rd_collection.id)).to be true
      expect(superadmin_user.submitter_collections.count).to eq Collection.count
    end

    it "gives access to research data collection to normal users" do
      expect(normal_user.can_admin?(pppl_collection)).to be false
      expect(normal_user.can_submit?(pppl_collection)).to be false
      expect(normal_user.can_admin?(rd_collection)).to be false
      expect(normal_user.can_submit?(rd_collection)).to be true
      expect(normal_user.submitter_collections.count).to eq 1
    end

    it "gives submit access PPPL collection to PPPL users" do
      expect(pppl_user.can_admin?(pppl_collection)).to be false
      expect(pppl_user.can_submit?(pppl_collection)).to be true
      expect(pppl_user.can_admin?(rd_collection)).to be false
      expect(pppl_user.can_submit?(rd_collection)).to be false
      expect(pppl_user.submitter_collections.count).to eq 1
    end
  end

  describe "#orcid" do
    let(:normal_user) { described_class.new }
    let(:orcid) { "0000-0003-1279-3709" }

    it "mutates the ORCID for a given User" do
      expect(normal_user.orcid).to be nil
      normal_user.orcid = orcid
      expect(normal_user.orcid).to eq(orcid)
    end

    context "with an existing ORCID" do
      let(:normal_user) { described_class.new(orcid: orcid) }

      it "accesses an existing ORCID for a given User" do
        expect(normal_user.orcid).to eq(orcid)
      end
    end
  end

  describe "ORCID validation" do
    let(:user) { described_class.new }
    it "performs ORCID validation on save" do
      user.orcid = "1234-1234-1234-1234"
      expect(user.save).to be true

      user.orcid = "1234-1234-1234-ABCD"
      expect(user.save).to be false

      user.orcid = ""
      expect(user.save).to be true
    end
  end
end
