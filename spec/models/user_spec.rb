# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  let(:access_token) { OmniAuth::AuthHash.new(provider: "cas", uid: "who", extra: { mail: "who@princeton.edu" }) }

  describe "#from_cas" do
    # Notice that we return an object even if it does not exist (yet) in the database
    it "returns a user object" do
      expect(described_class.from_cas(access_token)).to be_a described_class
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
end
