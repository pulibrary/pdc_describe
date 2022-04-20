# frozen_string_literal: true
require "rails_helper"

RSpec.describe Orcid, type: :model do
  it "validates ORCIDs" do
    expect(described_class.valid?("1234-5678-9012-1234")).to be true
    expect(described_class.valid?("01234-5678-9012-1234")).to be false
    expect(described_class.valid?("234-5678-9012-1234")).to be false
    expect(described_class.valid?("ABCD-5678-9012-1234")).to be false
    expect(described_class.valid?("")).to be false
  end

  it "produces the expected URL" do
    expect(described_class.url("1234-5678-9012-1234")).to eq "https://orcid.org/1234-5678-9012-1234"
  end
end
