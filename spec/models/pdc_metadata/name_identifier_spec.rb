# frozen_string_literal: true
require "rails_helper"

describe PDCMetadata::NameIdentifier, type: :model do
  context "Research Organization Registry (ROR)" do
    let(:value) { "https://ror.org/01bj3aw27" } # ROR for United States Department of Energy

    subject(:name_identifier) do
      described_class.new_ror(value)
    end

    it "returns the ROR identifier" do
      expect(name_identifier.ror_id).to eq "01bj3aw27"
    end

    it "returns the ROR url" do
      expect(name_identifier.ror_url).to eq value
    end
  end
end
