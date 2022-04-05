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
end
