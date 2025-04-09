# frozen_string_literal: true
require "rails_helper"

RSpec.describe PULS3Client do
  describe "initialize mode" do
    it "returns the correct config for PRECURATION" do
      s3 = described_class.new(PULS3Client::PRECURATION)
      expect(s3.config[:bucket]).to eq("example-bucket")
    end

    it "returns the correct config for POSTCURATION" do
      s3 = described_class.new(PULS3Client::POSTCURATION)
      expect(s3.config[:bucket]).to eq("example-bucket-post")
    end

    it "returns the correct config for PRESERVATION" do
      s3 = described_class.new(PULS3Client::PRESERVATION)
      expect(s3.config[:bucket]).to eq("example-bucket-preservation")
    end

    it "returns the correct config for EMBARGO" do
      s3 = described_class.new(PULS3Client::EMBARGO)
      expect(s3.config[:bucket]).to eq("example-bucket-embargo")
    end

    it "raises and error for other names" do
      s3 = described_class.new("other")
      expect { s3.config }.to raise_error "Invalid mode value: other"
    end
  end
end
